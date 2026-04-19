import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

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
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { order_id, gross_amount, cart_items } = await req.json();

    if (!order_id || !gross_amount || !cart_items) {
      throw new Error("Missing required payload fields");
    }

    // 1. Insert into transactions (PENDING state)
    const { error: txError } = await supabaseClient
      .from("transactions")
      .insert({
        id: order_id,
        transaction_type: "SALE",
        total_amount: gross_amount,
        payment_method: "QRIS",
        status: "PENDING", 
      });

    if (txError) throw new Error(`Transaction insert failed: \${txError.message}`);

    // 2. Insert transaction items
    const itemsToInsert = cart_items.map((item: any) => ({
      transaction_id: order_id,
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: item.price,
    }));

    const { error: itemError } = await supabaseClient
      .from("transaction_items")
      .insert(itemsToInsert);

    if (itemError) throw new Error(`Items insert failed: \${itemError.message}`);

    // 3. Call Midtrans Core API
    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const encodedKey = btoa(serverKey + ":");

    const itemDetails = cart_items.map((i: any) => ({
      id: i.product_id,
      price: Math.round(i.price),
      quantity: i.quantity,
      name: (i.name || "Item").substring(0, 50),
    }));

    const midtransReq = await fetch("https://api.sandbox.midtrans.com/v2/charge", {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": `Basic \${encodedKey}`
      },
      body: JSON.stringify({
        payment_type: "qris",
        transaction_details: {
          order_id: order_id,
          gross_amount: Math.round(gross_amount)
        },
        item_details: itemDetails,
      })
    });

    const midtransRes = await midtransReq.json();
    let qrUrl = null;

    // ── Midtrans Sandbox Fallback Mock ──
    if (midtransRes.status_code !== "201" && midtransRes.status_code !== "200") {
      console.warn("Falling back to MOCK QRIS Mode for MVP demonstration.");
      
      // Use qrserver API which supports cross-origin requests beautifully on Flutter Web
      const mockQrData = encodeURIComponent(`MOCK-QRIS-PAYMENT-\${order_id}`);
      qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=\${mockQrData}`;
      
    } else {
      const qrAction = midtransRes.actions?.find((a: any) => a.name === "generate-qr-code");
      qrUrl = qrAction?.url;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        order_id,
        qris_url: qrUrl,
        midtrans_response: midtransRes,
        is_mock: midtransRes.status_code !== "201" && midtransRes.status_code !== "200"
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
