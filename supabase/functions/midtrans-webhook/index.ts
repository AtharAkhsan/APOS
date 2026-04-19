import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    const {
      order_id,
      status_code,
      gross_amount,
      signature_key,
      transaction_status
    } = payload;

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    
    // Verify signature
    const inputString = `${order_id}${status_code}${gross_amount}${serverKey}`;
    const encoder = new TextEncoder();
    const data = encoder.encode(inputString);
    const hashBuffer = await crypto.subtle.digest("SHA-512", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const calculatedSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

    if (calculatedSignature !== signature_key) {
      console.warn("Invalid signature", { order_id });
      // Always return 200 to Midtrans to stop retries, even on signature fail
      return new Response("Invalid signature", { status: 200 });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    if (transaction_status === 'settlement' || transaction_status === 'capture') {
      // 1. Update Transaction to PAID
      const { data: txUpdate, error: txError } = await supabaseClient
        .from("transactions")
        .update({ status: "PAID" })
        .eq("id", order_id)
        .eq("status", "PENDING") // Idempotency check: only process if currently PENDING
        .select();

      // If no row was updated, it means it wasn't PENDING (already processed) or order_id doesn't exist
      if (!txUpdate || txUpdate.length === 0) {
        return new Response("Already processed or not found", { status: 200 });
      }

      // 2. Fetch Items for Stock & COGS Deduction
      const { data: items } = await supabaseClient
        .from("transaction_items")
        .select("product_id, quantity, unit_price")
        .eq("transaction_id", order_id);

      if (items && items.length > 0) {
        let totalSales = 0;
        let totalCOGS = 0;

        for (const item of items) {
          // Fetch current stock and purchase_price
          const { data: product } = await supabaseClient
            .from("products")
            .select("current_stock, purchase_price")
            .eq("id", item.product_id)
            .single();

          if (product) {
            // Deduct stock
            await supabaseClient
              .from("products")
              .update({ current_stock: product.current_stock - item.quantity })
              .eq("id", item.product_id);
            
            // Accumulate amounts
            totalSales += item.quantity * item.unit_price;
            totalCOGS += item.quantity * (product.purchase_price || 0);
          }
        }

        // 3. Accounting Engine (Double Entry)
        // a) Create Journal Entry
        const { data: journal } = await supabaseClient
          .from("journal_entries")
          .insert({
            transaction_id: order_id,
            description: `QRIS SALE: ${order_id}`
          })
          .select("id")
          .single();

        if (journal) {
          // Get Account IDs based on standard setup
          const { data: accounts } = await supabaseClient
            .from("accounts")
            .select("id, code")
            .in("code", ["1-1002", "4-4001", "5-5001", "1-1005"]); 
            // 1-1002 = Bank/QRIS, 4-4001 = Revenue, 5-5001 = COGS, 1-1005 = Inventory
            // (If 1-1002 doesn't exist, we could fallback to 1-1001 Cash, but assuming standard COA here)

          const accMap = new Map();
          accounts?.forEach(a => accMap.set(a.code, a.id));

          // If bank isn't found, fallback to cash 1-1001
          let bankId = accMap.get("1-1002");
          if (!bankId) {
             const { data: cashAcc } = await supabaseClient.from("accounts").select("id").eq("code", "1-1001").single();
             if (cashAcc) bankId = cashAcc.id;
          }

          // b) Ledger Entries
          const ledgerPayload = [];

          const revenueId = accMap.get("4-4001");
          // Debit Bank/Cash, Credit Revenue
          if (bankId && revenueId) {
             ledgerPayload.push({ journal_entry_id: journal.id, account_id: bankId, debit: totalSales, credit: 0 });
             ledgerPayload.push({ journal_entry_id: journal.id, account_id: revenueId, debit: 0, credit: totalSales });
          }

          const cogsId = accMap.get("5-5001");
          const inventoryId = accMap.get("1-1005");
          // Debit COGS, Credit Inventory
          if (cogsId && inventoryId && totalCOGS > 0) {
             ledgerPayload.push({ journal_entry_id: journal.id, account_id: cogsId, debit: totalCOGS, credit: 0 });
             ledgerPayload.push({ journal_entry_id: journal.id, account_id: inventoryId, debit: 0, credit: totalCOGS });
          }

          if (ledgerPayload.length > 0) {
            await supabaseClient.from("ledger_entries").insert(ledgerPayload);
          }
        }
      }

    } else if (['cancel', 'expire', 'deny'].includes(transaction_status)) {
      // Failed transaction, release anything PENDING
      await supabaseClient
        .from("transactions")
        .update({ status: transaction_status.toUpperCase() })
        .eq("id", order_id)
        .eq("status", "PENDING");
    }

    return new Response("OK", { status: 200 });

  } catch (error: any) {
    console.error("Webhook Error:", error.message);
    // Always return 200 to prevent Midtrans hammering your endpoint
    return new Response("Internal Error", { status: 200 });
  }
});
