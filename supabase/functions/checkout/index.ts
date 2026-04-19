// ============================================================
// Supabase Edge Function: checkout
// Processes a POS sale transaction atomically via RPC.
// ============================================================
// Deploy: supabase functions deploy checkout
// Invoke: POST /functions/v1/checkout
// ============================================================
// MVP MODE: Allows anon-key requests. staff_id is optional.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// ── Types ──────────────────────────────────────────────────

interface CartItem {
  product_id: string;
  quantity: number;
  price: number;
}

interface CheckoutPayload {
  cart_items: CartItem[];
  payment_method: string;
  staff_id: string | null;
  outlet_id: string;
}

interface CheckoutResult {
  success: boolean;
  transaction_id: string;
  reference_no: string;
  total_amount: number;
  total_cogs: number;
  payment_method: string;
  items: Array<{
    product_id: string;
    product_name: string;
    quantity: number;
    unit_price: number;
    subtotal: number;
  }>;
  journal_id: string;
  created_at: string;
}

// ── CORS Headers ───────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Constants ──────────────────────────────────────────────

// Anonymous checkout: staff_id will be null
// (transactions.created_by allows NULL via ON DELETE SET NULL)

// ── Validation Helpers ─────────────────────────────────────

function isValidUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value
  );
}

function validatePayload(body: unknown): CheckoutPayload {
  const payload = body as Record<string, unknown>;

  // ── cart_items ──
  if (!Array.isArray(payload.cart_items) || payload.cart_items.length === 0) {
    throw new Error("cart_items must be a non-empty array.");
  }

  for (let i = 0; i < payload.cart_items.length; i++) {
    const item = payload.cart_items[i] as Record<string, unknown>;
    const idx = `cart_items[${i}]`;

    if (!item.product_id || !isValidUUID(String(item.product_id))) {
      throw new Error(`${idx}.product_id must be a valid UUID.`);
    }
    if (
      typeof item.quantity !== "number" ||
      !Number.isInteger(item.quantity) ||
      item.quantity <= 0
    ) {
      throw new Error(`${idx}.quantity must be a positive integer.`);
    }
    if (typeof item.price !== "number" || item.price < 0) {
      throw new Error(`${idx}.price must be a non-negative number.`);
    }
  }

  // ── payment_method ──
  const ALLOWED_METHODS = ["CASH", "BANK_TRANSFER", "QRIS", "CREDIT_CARD", "DEBIT_CARD"];
  const method = String(payload.payment_method ?? "CASH").toUpperCase();

  if (!ALLOWED_METHODS.includes(method)) {
    throw new Error(
      `payment_method must be one of: ${ALLOWED_METHODS.join(", ")}.`
    );
  }

  // ── staff_id (optional for MVP) ──
  let staffId: string | null = null;
  if (payload.staff_id && isValidUUID(String(payload.staff_id))) {
    staffId = String(payload.staff_id);
  }
  // If not provided or invalid, use null (anonymous checkout)
  if (!staffId) {
    staffId = null;
  }

  // ── outlet_id ──
  if (!payload.outlet_id || !isValidUUID(String(payload.outlet_id))) {
    throw new Error("outlet_id must be a valid UUID.");
  }

  return {
    cart_items: payload.cart_items as CartItem[],
    payment_method: method,
    staff_id: staffId,
    outlet_id: String(payload.outlet_id),
  };
}

// ── Main Handler ───────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only accept POST
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method not allowed." }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // ── 1. Parse & validate ──────────────────────────────
    const rawBody = await req.json();
    const payload = validatePayload(rawBody);

    // ── 2. Build Supabase client (service role for full access) ──
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // ── 3. Server-side stock validation ──────────────────
    const productIds = payload.cart_items.map((item) => item.product_id);

    // Fetch products to ensure they exist and get names for errors
    const { data: products, error: productError } = await supabase
      .from("products")
      .select("id, name, sku")
      .in("id", productIds);

    if (productError) {
      throw new Error(`Failed to verify products: ${productError.message}`);
    }

    // Fetch stock for this outlet
    const { data: stockData, error: stockError } = await supabase
      .from("product_stock")
      .select("product_id, current_stock")
      .eq("outlet_id", payload.outlet_id)
      .in("product_id", productIds);

    if (stockError) {
      throw new Error(`Failed to verify stock: ${stockError.message}`);
    }

    // Build lookup maps
    const productMap = new Map<string, { name: string; sku: string }>();
    for (const p of products ?? []) {
      productMap.set(p.id, { name: p.name, sku: p.sku });
    }

    const stockMap = new Map<string, number>();
    for (const s of stockData ?? []) {
      stockMap.set(s.product_id, s.current_stock);
    }

    // Validate each cart item against actual DB stock
    for (const item of payload.cart_items) {
      const product = productMap.get(item.product_id);
      const stock = stockMap.get(item.product_id) ?? 0;

      if (!product) {
        throw new Error(`Product not found: ${item.product_id}`);
      }

      if (item.quantity > stock) {
        throw new Error(
          `Insufficient stock for "${product.name}" (SKU: ${product.sku}). ` +
          `Available: ${stock}, Requested: ${item.quantity}.`
        );
      }
    }

    // ── 4. Call the atomic RPC ────────────────────────────
    const { data, error } = await supabase.rpc("process_checkout", {
      p_cart_items: payload.cart_items,
      p_payment_method: payload.payment_method,
      p_staff_id: payload.staff_id,
      p_outlet_id: payload.outlet_id,
    });

    if (error) {
      const status = error.message.includes("Insufficient stock") ? 409 : 400;

      return new Response(
        JSON.stringify({
          success: false,
          error: error.message,
          code: error.code ?? "RPC_ERROR",
        }),
        {
          status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const result = data as CheckoutResult;

    // ── 5. Return success ────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          transaction_id: result.transaction_id,
          reference_no: result.reference_no,
          total_amount: result.total_amount,
          total_cogs: result.total_cogs,
          payment_method: result.payment_method,
          items: result.items,
          journal_id: result.journal_id,
          created_at: result.created_at,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal server error.";

    // Map error types to HTTP status codes
    let status = 500;
    if (message.includes("must be")) status = 422;
    else if (message.includes("Insufficient stock")) status = 409;
    else if (message.includes("not found")) status = 404;

    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
