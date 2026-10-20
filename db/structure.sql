SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: forbid_ledger_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.forbid_ledger_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: post a reversing entry instead of %', TG_TABLE_NAME, TG_OP;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approvals (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    subject_type character varying NOT NULL,
    subject_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    reason text,
    amount_paise bigint,
    requested_by_id bigint,
    decided_by_id bigint,
    decided_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.approvals_id_seq OWNED BY public.approvals.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    user_id bigint,
    subject_type character varying,
    subject_id bigint,
    action character varying NOT NULL,
    changeset jsonb DEFAULT '{}'::jsonb NOT NULL,
    device character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: brand_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_claims (
    id bigint NOT NULL,
    number character varying NOT NULL,
    brand_id bigint NOT NULL,
    supplier_id bigint,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    sent_on date,
    challan_no character varying,
    credit_note_ref character varying,
    settled_on date,
    credited_paise bigint DEFAULT 0 NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: brand_claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.brand_claims_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brand_claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.brand_claims_id_seq OWNED BY public.brand_claims.id;


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id bigint NOT NULL,
    name character varying NOT NULL,
    warranty_months integer DEFAULT 12 NOT NULL,
    claim_contact character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: brands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.brands_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.brands_id_seq OWNED BY public.brands.id;


--
-- Name: broadcasts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.broadcasts (
    id bigint NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    market_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    recipients integer DEFAULT 0 NOT NULL,
    created_by_id bigint,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: broadcasts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.broadcasts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: broadcasts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.broadcasts_id_seq OWNED BY public.broadcasts.id;


--
-- Name: credit_note_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_note_lines (
    id bigint NOT NULL,
    credit_note_id bigint NOT NULL,
    product_id bigint NOT NULL,
    invoice_line_id bigint,
    quantity integer NOT NULL,
    rate_paise bigint NOT NULL,
    gst_rate numeric(5,2) NOT NULL,
    taxable_paise bigint NOT NULL,
    tax_paise bigint NOT NULL,
    total_paise bigint NOT NULL
);


--
-- Name: credit_note_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_note_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_note_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_note_lines_id_seq OWNED BY public.credit_note_lines.id;


--
-- Name: credit_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_notes (
    id bigint NOT NULL,
    number character varying NOT NULL,
    fy character varying NOT NULL,
    customer_id bigint NOT NULL,
    invoice_id bigint,
    note_date date NOT NULL,
    reason character varying NOT NULL,
    restock_bucket character varying,
    taxable_paise bigint DEFAULT 0 NOT NULL,
    cgst_paise bigint DEFAULT 0 NOT NULL,
    sgst_paise bigint DEFAULT 0 NOT NULL,
    igst_paise bigint DEFAULT 0 NOT NULL,
    total_paise bigint DEFAULT 0 NOT NULL,
    created_by_id bigint,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    round_off_paise bigint DEFAULT 0 NOT NULL
);


--
-- Name: credit_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_notes_id_seq OWNED BY public.credit_notes.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id bigint NOT NULL,
    code character varying NOT NULL,
    shop_name character varying NOT NULL,
    owner_name character varying,
    phone character varying NOT NULL,
    gstin character varying,
    state_code character varying,
    address text,
    market_id bigint,
    credit_limit_paise bigint DEFAULT 0 NOT NULL,
    price_tier character varying DEFAULT 'wholesale'::character varying NOT NULL,
    marketing_opt_in boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deliveries (
    id bigint NOT NULL,
    dispatch_run_id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    otp_code character varying,
    otp_verified boolean DEFAULT false NOT NULL,
    proof character varying,
    delivered_at timestamp(6) without time zone,
    delivered_by_id bigint,
    notes text,
    client_uuid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    otp_failures integer DEFAULT 0 NOT NULL
);


--
-- Name: deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deliveries_id_seq OWNED BY public.deliveries.id;


--
-- Name: dispatch_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispatch_runs (
    id bigint NOT NULL,
    market_id bigint NOT NULL,
    run_date date NOT NULL,
    delivery_person_id bigint,
    status character varying DEFAULT 'planned'::character varying NOT NULL,
    vehicle character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dispatch_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dispatch_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dispatch_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dispatch_runs_id_seq OWNED BY public.dispatch_runs.id;


--
-- Name: document_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_sequences (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    fy character varying NOT NULL,
    last_number integer DEFAULT 0 NOT NULL
);


--
-- Name: document_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_sequences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_sequences_id_seq OWNED BY public.document_sequences.id;


--
-- Name: invoice_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_lines (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    product_id bigint NOT NULL,
    description character varying NOT NULL,
    hsn character varying NOT NULL,
    quantity integer NOT NULL,
    rate_paise bigint NOT NULL,
    discount_pct numeric(5,2) DEFAULT 0.0 NOT NULL,
    gst_rate numeric(5,2) NOT NULL,
    taxable_paise bigint NOT NULL,
    cgst_paise bigint DEFAULT 0 NOT NULL,
    sgst_paise bigint DEFAULT 0 NOT NULL,
    igst_paise bigint DEFAULT 0 NOT NULL,
    total_paise bigint NOT NULL
);


--
-- Name: invoice_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoice_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoice_lines_id_seq OWNED BY public.invoice_lines.id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id bigint NOT NULL,
    number character varying NOT NULL,
    fy character varying NOT NULL,
    customer_id bigint NOT NULL,
    order_id bigint,
    invoice_date date NOT NULL,
    due_date date NOT NULL,
    status character varying DEFAULT 'posted'::character varying NOT NULL,
    channel character varying DEFAULT 'counter'::character varying NOT NULL,
    prices_include_tax boolean DEFAULT false NOT NULL,
    bill_to_name character varying NOT NULL,
    bill_to_gstin character varying,
    place_of_supply character varying NOT NULL,
    bill_to_address text,
    taxable_paise bigint DEFAULT 0 NOT NULL,
    cgst_paise bigint DEFAULT 0 NOT NULL,
    sgst_paise bigint DEFAULT 0 NOT NULL,
    igst_paise bigint DEFAULT 0 NOT NULL,
    round_off_paise bigint DEFAULT 0 NOT NULL,
    total_paise bigint DEFAULT 0 NOT NULL,
    eway_required boolean DEFAULT false NOT NULL,
    eway_bill_no character varying,
    irn character varying,
    posted_by_id bigint,
    cancelled_by_id bigint,
    cancelled_at timestamp(6) without time zone,
    cancel_reason character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoices_id_seq OWNED BY public.invoices.id;


--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id bigint NOT NULL,
    party_type character varying NOT NULL,
    party_id bigint NOT NULL,
    entry_date date NOT NULL,
    debit_paise bigint DEFAULT 0 NOT NULL,
    credit_paise bigint DEFAULT 0 NOT NULL,
    entry_type character varying NOT NULL,
    document_type character varying,
    document_id bigint,
    narration character varying,
    user_id bigint,
    device character varying,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT ledger_one_side CHECK (((debit_paise >= 0) AND (credit_paise >= 0) AND ((debit_paise > 0) <> (credit_paise > 0))))
);


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ledger_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ledger_entries_id_seq OWNED BY public.ledger_entries.id;


--
-- Name: markets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.markets (
    id bigint NOT NULL,
    name character varying NOT NULL,
    delivery_weekday integer,
    salesman_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: markets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.markets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: markets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.markets_id_seq OWNED BY public.markets.id;


--
-- Name: order_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_lines (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint,
    quantity integer NOT NULL,
    rate_paise bigint,
    discount_pct numeric(5,2) DEFAULT 0.0 NOT NULL,
    source_text character varying,
    confidence numeric(4,3),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: order_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_lines_id_seq OWNED BY public.order_lines.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    number character varying NOT NULL,
    customer_id bigint NOT NULL,
    channel character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    raw_message text,
    notes text,
    created_by_id bigint,
    client_uuid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: payment_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_allocations (
    id bigint NOT NULL,
    payment_id bigint NOT NULL,
    invoice_id bigint,
    amount_paise bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    ledger_entry_id bigint,
    CONSTRAINT allocation_one_target CHECK (((invoice_id IS NULL) <> (ledger_entry_id IS NULL)))
);


--
-- Name: payment_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_allocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_allocations_id_seq OWNED BY public.payment_allocations.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    number character varying NOT NULL,
    customer_id bigint NOT NULL,
    amount_paise bigint NOT NULL,
    mode character varying NOT NULL,
    reference character varying,
    received_on date NOT NULL,
    status character varying DEFAULT 'cleared'::character varying NOT NULL,
    collected_by_id bigint,
    client_uuid character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payment_positive CHECK ((amount_paise > 0))
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    brand_id bigint NOT NULL,
    sku character varying NOT NULL,
    name character varying NOT NULL,
    model character varying,
    wattage character varying,
    hsn character varying NOT NULL,
    gst_rate numeric(5,2) DEFAULT 18.0 NOT NULL,
    mrp_paise bigint DEFAULT 0 NOT NULL,
    retail_paise bigint DEFAULT 0 NOT NULL,
    wholesale_paise bigint DEFAULT 0 NOT NULL,
    purchase_paise bigint DEFAULT 0 NOT NULL,
    reorder_level integer DEFAULT 0 NOT NULL,
    warranty_months integer,
    unit character varying DEFAULT 'pc'::character varying NOT NULL,
    aliases text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: purchase_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_lines (
    id bigint NOT NULL,
    purchase_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity integer NOT NULL,
    rate_paise bigint NOT NULL,
    gst_rate numeric(5,2) NOT NULL,
    taxable_paise bigint NOT NULL,
    tax_paise bigint NOT NULL
);


--
-- Name: purchase_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.purchase_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: purchase_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.purchase_lines_id_seq OWNED BY public.purchase_lines.id;


--
-- Name: purchases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchases (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    bill_no character varying NOT NULL,
    bill_date date NOT NULL,
    taxable_paise bigint DEFAULT 0 NOT NULL,
    tax_paise bigint DEFAULT 0 NOT NULL,
    total_paise bigint DEFAULT 0 NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: purchases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.purchases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: purchases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.purchases_id_seq OWNED BY public.purchases.id;


--
-- Name: replacements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.replacements (
    id bigint NOT NULL,
    number character varying NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    invoice_id bigint,
    sold_on date,
    warranty_until date,
    warranty_valid boolean DEFAULT false NOT NULL,
    outcome character varying NOT NULL,
    claim_status character varying DEFAULT 'awaiting'::character varying NOT NULL,
    brand_claim_id bigint,
    credited_paise bigint DEFAULT 0 NOT NULL,
    channel character varying DEFAULT 'counter'::character varying NOT NULL,
    defect character varying,
    serial_no character varying,
    logged_by_id bigint,
    client_uuid character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: replacements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.replacements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replacements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.replacements_id_seq OWNED BY public.replacements.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    device_label character varying
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: shop_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shop_settings (
    id bigint NOT NULL,
    name character varying DEFAULT 'My Electricals'::character varying NOT NULL,
    legal_name character varying,
    gstin character varying,
    state_code character varying DEFAULT '27'::character varying NOT NULL,
    address text,
    phone character varying,
    email character varying,
    upi_id character varying,
    invoice_prefix character varying DEFAULT 'INV'::character varying NOT NULL,
    credit_days integer DEFAULT 30 NOT NULL,
    eway_threshold_paise bigint DEFAULT 5000000 NOT NULL,
    einvoice_enabled boolean DEFAULT false NOT NULL,
    claim_flag_days integer DEFAULT 45 NOT NULL,
    discount_approval_pct numeric(5,2) DEFAULT 10.0 NOT NULL,
    writeoff_approval_paise bigint DEFAULT 500000 NOT NULL,
    whatsapp_provider character varying DEFAULT 'log'::character varying NOT NULL,
    bank_details text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: shop_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shop_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shop_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shop_settings_id_seq OWNED BY public.shop_settings.id;


--
-- Name: solid_cable_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_cable_messages (
    id bigint NOT NULL,
    channel bytea NOT NULL,
    payload bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    channel_hash bigint NOT NULL
);


--
-- Name: solid_cable_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_cable_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_cable_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_cable_messages_id_seq OWNED BY public.solid_cable_messages.id;


--
-- Name: solid_cache_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_cache_entries (
    id bigint NOT NULL,
    key bytea NOT NULL,
    value bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key_hash bigint NOT NULL,
    byte_size integer NOT NULL
);


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_cache_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_cache_entries_id_seq OWNED BY public.solid_cache_entries.id;


--
-- Name: solid_queue_batch_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_batch_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    batch_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_batch_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_batch_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_batch_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_batch_executions_id_seq OWNED BY public.solid_queue_batch_executions.id;


--
-- Name: solid_queue_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_batches (
    id bigint NOT NULL,
    active_job_batch_id character varying,
    description character varying,
    on_finish text,
    on_success text,
    on_failure text,
    metadata text,
    total_jobs integer DEFAULT 0 NOT NULL,
    completed_jobs integer DEFAULT 0 NOT NULL,
    failed_jobs integer DEFAULT 0 NOT NULL,
    enqueued_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_batches_id_seq OWNED BY public.solid_queue_batches.id;


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    batch_id bigint
);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: stock_count_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_count_lines (
    id bigint NOT NULL,
    stock_count_id bigint NOT NULL,
    product_id bigint NOT NULL,
    system_qty integer NOT NULL,
    counted_qty integer,
    reason character varying
);


--
-- Name: stock_count_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stock_count_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_count_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stock_count_lines_id_seq OWNED BY public.stock_count_lines.id;


--
-- Name: stock_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_counts (
    id bigint NOT NULL,
    count_date date NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    counted_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stock_counts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stock_counts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_counts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stock_counts_id_seq OWNED BY public.stock_counts.id;


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_movements (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    bucket character varying NOT NULL,
    quantity integer NOT NULL,
    reason character varying NOT NULL,
    document_type character varying,
    document_id bigint,
    user_id bigint,
    device character varying,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT stock_movement_bucket CHECK (((bucket)::text = ANY (ARRAY[('sellable'::character varying)::text, ('awaiting_claim'::character varying)::text, ('with_brand'::character varying)::text, ('written_off'::character varying)::text]))),
    CONSTRAINT stock_movement_nonzero CHECK ((quantity <> 0))
);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stock_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stock_movements_id_seq OWNED BY public.stock_movements.id;


--
-- Name: supplier_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payments (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    amount_paise bigint NOT NULL,
    mode character varying NOT NULL,
    reference character varying,
    paid_on date NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: supplier_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.supplier_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: supplier_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.supplier_payments_id_seq OWNED BY public.supplier_payments.id;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id bigint NOT NULL,
    name character varying NOT NULL,
    brand_id bigint,
    gstin character varying,
    state_code character varying,
    phone character varying,
    address text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: suppliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.suppliers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: suppliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.suppliers_id_seq OWNED BY public.suppliers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    role character varying DEFAULT 'counter'::character varying NOT NULL,
    phone character varying,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: whatsapp_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_messages (
    id bigint NOT NULL,
    customer_id bigint,
    phone character varying NOT NULL,
    direction character varying NOT NULL,
    category character varying NOT NULL,
    template character varying,
    body text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'queued'::character varying NOT NULL,
    provider_message_id character varying,
    cost_paise integer DEFAULT 0 NOT NULL,
    document_type character varying,
    document_id bigint,
    error character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: whatsapp_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.whatsapp_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whatsapp_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.whatsapp_messages_id_seq OWNED BY public.whatsapp_messages.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals ALTER COLUMN id SET DEFAULT nextval('public.approvals_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: brand_claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_claims ALTER COLUMN id SET DEFAULT nextval('public.brand_claims_id_seq'::regclass);


--
-- Name: brands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands ALTER COLUMN id SET DEFAULT nextval('public.brands_id_seq'::regclass);


--
-- Name: broadcasts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.broadcasts ALTER COLUMN id SET DEFAULT nextval('public.broadcasts_id_seq'::regclass);


--
-- Name: credit_note_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_lines ALTER COLUMN id SET DEFAULT nextval('public.credit_note_lines_id_seq'::regclass);


--
-- Name: credit_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes ALTER COLUMN id SET DEFAULT nextval('public.credit_notes_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: deliveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries ALTER COLUMN id SET DEFAULT nextval('public.deliveries_id_seq'::regclass);


--
-- Name: dispatch_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_runs ALTER COLUMN id SET DEFAULT nextval('public.dispatch_runs_id_seq'::regclass);


--
-- Name: document_sequences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences ALTER COLUMN id SET DEFAULT nextval('public.document_sequences_id_seq'::regclass);


--
-- Name: invoice_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines ALTER COLUMN id SET DEFAULT nextval('public.invoice_lines_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices ALTER COLUMN id SET DEFAULT nextval('public.invoices_id_seq'::regclass);


--
-- Name: ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.ledger_entries_id_seq'::regclass);


--
-- Name: markets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets ALTER COLUMN id SET DEFAULT nextval('public.markets_id_seq'::regclass);


--
-- Name: order_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines ALTER COLUMN id SET DEFAULT nextval('public.order_lines_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: payment_allocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocations ALTER COLUMN id SET DEFAULT nextval('public.payment_allocations_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: purchase_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_lines ALTER COLUMN id SET DEFAULT nextval('public.purchase_lines_id_seq'::regclass);


--
-- Name: purchases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases ALTER COLUMN id SET DEFAULT nextval('public.purchases_id_seq'::regclass);


--
-- Name: replacements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements ALTER COLUMN id SET DEFAULT nextval('public.replacements_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: shop_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_settings ALTER COLUMN id SET DEFAULT nextval('public.shop_settings_id_seq'::regclass);


--
-- Name: solid_cable_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cable_messages ALTER COLUMN id SET DEFAULT nextval('public.solid_cable_messages_id_seq'::regclass);


--
-- Name: solid_cache_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries ALTER COLUMN id SET DEFAULT nextval('public.solid_cache_entries_id_seq'::regclass);


--
-- Name: solid_queue_batch_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_batch_executions_id_seq'::regclass);


--
-- Name: solid_queue_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batches ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_batches_id_seq'::regclass);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: stock_count_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_lines ALTER COLUMN id SET DEFAULT nextval('public.stock_count_lines_id_seq'::regclass);


--
-- Name: stock_counts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_counts ALTER COLUMN id SET DEFAULT nextval('public.stock_counts_id_seq'::regclass);


--
-- Name: stock_movements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements ALTER COLUMN id SET DEFAULT nextval('public.stock_movements_id_seq'::regclass);


--
-- Name: supplier_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments ALTER COLUMN id SET DEFAULT nextval('public.supplier_payments_id_seq'::regclass);


--
-- Name: suppliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN id SET DEFAULT nextval('public.suppliers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: whatsapp_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_messages ALTER COLUMN id SET DEFAULT nextval('public.whatsapp_messages_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: brand_claims brand_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_claims
    ADD CONSTRAINT brand_claims_pkey PRIMARY KEY (id);


--
-- Name: brands brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_pkey PRIMARY KEY (id);


--
-- Name: broadcasts broadcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.broadcasts
    ADD CONSTRAINT broadcasts_pkey PRIMARY KEY (id);


--
-- Name: credit_note_lines credit_note_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_lines
    ADD CONSTRAINT credit_note_lines_pkey PRIMARY KEY (id);


--
-- Name: credit_notes credit_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT credit_notes_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: dispatch_runs dispatch_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_runs
    ADD CONSTRAINT dispatch_runs_pkey PRIMARY KEY (id);


--
-- Name: document_sequences document_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences
    ADD CONSTRAINT document_sequences_pkey PRIMARY KEY (id);


--
-- Name: invoice_lines invoice_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: markets markets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_pkey PRIMARY KEY (id);


--
-- Name: order_lines order_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines
    ADD CONSTRAINT order_lines_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: payment_allocations payment_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocations
    ADD CONSTRAINT payment_allocations_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: purchase_lines purchase_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_lines
    ADD CONSTRAINT purchase_lines_pkey PRIMARY KEY (id);


--
-- Name: purchases purchases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT purchases_pkey PRIMARY KEY (id);


--
-- Name: replacements replacements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT replacements_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: shop_settings shop_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_settings
    ADD CONSTRAINT shop_settings_pkey PRIMARY KEY (id);


--
-- Name: solid_cable_messages solid_cable_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cable_messages
    ADD CONSTRAINT solid_cable_messages_pkey PRIMARY KEY (id);


--
-- Name: solid_cache_entries solid_cache_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries
    ADD CONSTRAINT solid_cache_entries_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_batch_executions solid_queue_batch_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT solid_queue_batch_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_batches solid_queue_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batches
    ADD CONSTRAINT solid_queue_batches_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: stock_count_lines stock_count_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_lines
    ADD CONSTRAINT stock_count_lines_pkey PRIMARY KEY (id);


--
-- Name: stock_counts stock_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_counts
    ADD CONSTRAINT stock_counts_pkey PRIMARY KEY (id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);


--
-- Name: supplier_payments supplier_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_messages whatsapp_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_approvals_on_decided_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approvals_on_decided_by_id ON public.approvals USING btree (decided_by_id);


--
-- Name: index_approvals_on_requested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approvals_on_requested_by_id ON public.approvals USING btree (requested_by_id);


--
-- Name: index_approvals_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approvals_on_subject ON public.approvals USING btree (subject_type, subject_id);


--
-- Name: index_audit_events_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_subject ON public.audit_events USING btree (subject_type, subject_id);


--
-- Name: index_audit_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_user_id ON public.audit_events USING btree (user_id);


--
-- Name: index_brand_claims_on_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brand_claims_on_brand_id ON public.brand_claims USING btree (brand_id);


--
-- Name: index_brand_claims_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brand_claims_on_created_by_id ON public.brand_claims USING btree (created_by_id);


--
-- Name: index_brand_claims_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brand_claims_on_number ON public.brand_claims USING btree (number);


--
-- Name: index_brand_claims_on_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brand_claims_on_supplier_id ON public.brand_claims USING btree (supplier_id);


--
-- Name: index_brands_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brands_on_name ON public.brands USING btree (name);


--
-- Name: index_broadcasts_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_broadcasts_on_created_by_id ON public.broadcasts USING btree (created_by_id);


--
-- Name: index_credit_note_lines_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_lines_on_credit_note_id ON public.credit_note_lines USING btree (credit_note_id);


--
-- Name: index_credit_note_lines_on_invoice_line_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_lines_on_invoice_line_id ON public.credit_note_lines USING btree (invoice_line_id);


--
-- Name: index_credit_note_lines_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_lines_on_product_id ON public.credit_note_lines USING btree (product_id);


--
-- Name: index_credit_notes_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_created_by_id ON public.credit_notes USING btree (created_by_id);


--
-- Name: index_credit_notes_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_customer_id ON public.credit_notes USING btree (customer_id);


--
-- Name: index_credit_notes_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_invoice_id ON public.credit_notes USING btree (invoice_id);


--
-- Name: index_credit_notes_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_credit_notes_on_number ON public.credit_notes USING btree (number);


--
-- Name: index_customers_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_code ON public.customers USING btree (code);


--
-- Name: index_customers_on_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_market_id ON public.customers USING btree (market_id);


--
-- Name: index_customers_on_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_phone ON public.customers USING btree (phone);


--
-- Name: index_deliveries_on_delivered_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliveries_on_delivered_by_id ON public.deliveries USING btree (delivered_by_id);


--
-- Name: index_deliveries_on_dispatch_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliveries_on_dispatch_run_id ON public.deliveries USING btree (dispatch_run_id);


--
-- Name: index_deliveries_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deliveries_on_invoice_id ON public.deliveries USING btree (invoice_id);


--
-- Name: index_dispatch_runs_on_delivery_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dispatch_runs_on_delivery_person_id ON public.dispatch_runs USING btree (delivery_person_id);


--
-- Name: index_dispatch_runs_on_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dispatch_runs_on_market_id ON public.dispatch_runs USING btree (market_id);


--
-- Name: index_dispatch_runs_on_market_id_and_run_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dispatch_runs_on_market_id_and_run_date ON public.dispatch_runs USING btree (market_id, run_date);


--
-- Name: index_document_sequences_on_kind_and_fy; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_sequences_on_kind_and_fy ON public.document_sequences USING btree (kind, fy);


--
-- Name: index_invoice_lines_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_lines_on_invoice_id ON public.invoice_lines USING btree (invoice_id);


--
-- Name: index_invoice_lines_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_lines_on_product_id ON public.invoice_lines USING btree (product_id);


--
-- Name: index_invoices_on_cancelled_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_cancelled_by_id ON public.invoices USING btree (cancelled_by_id);


--
-- Name: index_invoices_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_customer_id ON public.invoices USING btree (customer_id);


--
-- Name: index_invoices_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_on_number ON public.invoices USING btree (number);


--
-- Name: index_invoices_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_order_id ON public.invoices USING btree (order_id);


--
-- Name: index_invoices_on_posted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_posted_by_id ON public.invoices USING btree (posted_by_id);


--
-- Name: index_ledger_entries_on_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_document ON public.ledger_entries USING btree (document_type, document_id);


--
-- Name: index_ledger_entries_on_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_party ON public.ledger_entries USING btree (party_type, party_id);


--
-- Name: index_ledger_entries_on_party_type_and_party_id_and_entry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_party_type_and_party_id_and_entry_date ON public.ledger_entries USING btree (party_type, party_id, entry_date);


--
-- Name: index_ledger_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_user_id ON public.ledger_entries USING btree (user_id);


--
-- Name: index_markets_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_markets_on_name ON public.markets USING btree (name);


--
-- Name: index_markets_on_salesman_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_markets_on_salesman_id ON public.markets USING btree (salesman_id);


--
-- Name: index_order_lines_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_lines_on_order_id ON public.order_lines USING btree (order_id);


--
-- Name: index_order_lines_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_lines_on_product_id ON public.order_lines USING btree (product_id);


--
-- Name: index_orders_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_orders_on_client_uuid ON public.orders USING btree (client_uuid);


--
-- Name: index_orders_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_created_by_id ON public.orders USING btree (created_by_id);


--
-- Name: index_orders_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_customer_id ON public.orders USING btree (customer_id);


--
-- Name: index_orders_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_orders_on_number ON public.orders USING btree (number);


--
-- Name: index_payment_allocations_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_allocations_on_invoice_id ON public.payment_allocations USING btree (invoice_id);


--
-- Name: index_payment_allocations_on_ledger_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_allocations_on_ledger_entry_id ON public.payment_allocations USING btree (ledger_entry_id);


--
-- Name: index_payment_allocations_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_allocations_on_payment_id ON public.payment_allocations USING btree (payment_id);


--
-- Name: index_payments_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_client_uuid ON public.payments USING btree (client_uuid);


--
-- Name: index_payments_on_collected_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_collected_by_id ON public.payments USING btree (collected_by_id);


--
-- Name: index_payments_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_customer_id ON public.payments USING btree (customer_id);


--
-- Name: index_payments_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_number ON public.payments USING btree (number);


--
-- Name: index_products_on_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_brand_id ON public.products USING btree (brand_id);


--
-- Name: index_products_on_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_products_on_sku ON public.products USING btree (sku);


--
-- Name: index_purchase_lines_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_purchase_lines_on_product_id ON public.purchase_lines USING btree (product_id);


--
-- Name: index_purchase_lines_on_purchase_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_purchase_lines_on_purchase_id ON public.purchase_lines USING btree (purchase_id);


--
-- Name: index_purchases_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_purchases_on_created_by_id ON public.purchases USING btree (created_by_id);


--
-- Name: index_purchases_on_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_purchases_on_supplier_id ON public.purchases USING btree (supplier_id);


--
-- Name: index_purchases_on_supplier_id_and_bill_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_purchases_on_supplier_id_and_bill_no ON public.purchases USING btree (supplier_id, bill_no);


--
-- Name: index_replacements_on_brand_claim_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_replacements_on_brand_claim_id ON public.replacements USING btree (brand_claim_id);


--
-- Name: index_replacements_on_client_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_replacements_on_client_uuid ON public.replacements USING btree (client_uuid);


--
-- Name: index_replacements_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_replacements_on_customer_id ON public.replacements USING btree (customer_id);


--
-- Name: index_replacements_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_replacements_on_invoice_id ON public.replacements USING btree (invoice_id);


--
-- Name: index_replacements_on_logged_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_replacements_on_logged_by_id ON public.replacements USING btree (logged_by_id);


--
-- Name: index_replacements_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_replacements_on_number ON public.replacements USING btree (number);


--
-- Name: index_replacements_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_replacements_on_product_id ON public.replacements USING btree (product_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_solid_cable_messages_on_channel_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cable_messages_on_channel_hash ON public.solid_cable_messages USING btree (channel_hash);


--
-- Name: index_solid_cable_messages_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cable_messages_on_created_at ON public.solid_cable_messages USING btree (created_at);


--
-- Name: index_solid_cache_entries_on_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_byte_size ON public.solid_cache_entries USING btree (byte_size);


--
-- Name: index_solid_cache_entries_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON public.solid_cache_entries USING btree (key_hash);


--
-- Name: index_solid_cache_entries_on_key_hash_and_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON public.solid_cache_entries USING btree (key_hash, byte_size);


--
-- Name: index_solid_queue_batch_executions_on_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_batch_executions_on_batch_id ON public.solid_queue_batch_executions USING btree (batch_id);


--
-- Name: index_solid_queue_batch_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_batch_executions_on_job_id ON public.solid_queue_batch_executions USING btree (job_id);


--
-- Name: index_solid_queue_batches_on_active_job_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_batches_on_active_job_batch_id ON public.solid_queue_batches USING btree (active_job_batch_id);


--
-- Name: index_solid_queue_batches_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_batches_on_finished_at ON public.solid_queue_batches USING btree (finished_at);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_batch_id ON public.solid_queue_jobs USING btree (batch_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_stock_count_lines_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_count_lines_on_product_id ON public.stock_count_lines USING btree (product_id);


--
-- Name: index_stock_count_lines_on_stock_count_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_count_lines_on_stock_count_id ON public.stock_count_lines USING btree (stock_count_id);


--
-- Name: index_stock_counts_on_counted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_counts_on_counted_by_id ON public.stock_counts USING btree (counted_by_id);


--
-- Name: index_stock_movements_on_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_document ON public.stock_movements USING btree (document_type, document_id);


--
-- Name: index_stock_movements_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_product_id ON public.stock_movements USING btree (product_id);


--
-- Name: index_stock_movements_on_product_id_and_bucket; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_product_id_and_bucket ON public.stock_movements USING btree (product_id, bucket);


--
-- Name: index_stock_movements_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_user_id ON public.stock_movements USING btree (user_id);


--
-- Name: index_supplier_payments_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_payments_on_created_by_id ON public.supplier_payments USING btree (created_by_id);


--
-- Name: index_supplier_payments_on_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_payments_on_supplier_id ON public.supplier_payments USING btree (supplier_id);


--
-- Name: index_suppliers_on_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_brand_id ON public.suppliers USING btree (brand_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_whatsapp_messages_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_whatsapp_messages_on_customer_id ON public.whatsapp_messages USING btree (customer_id);


--
-- Name: index_whatsapp_messages_on_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_whatsapp_messages_on_document ON public.whatsapp_messages USING btree (document_type, document_id);


--
-- Name: ledger_entries ledger_entries_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ledger_entries_append_only BEFORE DELETE OR UPDATE ON public.ledger_entries FOR EACH ROW EXECUTE FUNCTION public.forbid_ledger_change();


--
-- Name: stock_movements stock_movements_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stock_movements_append_only BEFORE DELETE OR UPDATE ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION public.forbid_ledger_change();


--
-- Name: invoices fk_rails_00f2fc9b72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_00f2fc9b72 FOREIGN KEY (cancelled_by_id) REFERENCES public.users(id);


--
-- Name: stock_count_lines fk_rails_039c3d997e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_lines
    ADD CONSTRAINT fk_rails_039c3d997e FOREIGN KEY (stock_count_id) REFERENCES public.stock_counts(id);


--
-- Name: stock_counts fk_rails_0c19993b67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_counts
    ADD CONSTRAINT fk_rails_0c19993b67 FOREIGN KEY (counted_by_id) REFERENCES public.users(id);


--
-- Name: invoices fk_rails_0d349e632f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_0d349e632f FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: brand_claims fk_rails_0eae62a0e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_claims
    ADD CONSTRAINT fk_rails_0eae62a0e2 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: credit_note_lines fk_rails_1032da1ff5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_lines
    ADD CONSTRAINT fk_rails_1032da1ff5 FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: purchase_lines fk_rails_16af0d873e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_lines
    ADD CONSTRAINT fk_rails_16af0d873e FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: supplier_payments fk_rails_1846f352d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_rails_1846f352d5 FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: markets fk_rails_1b895b21f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT fk_rails_1b895b21f8 FOREIGN KEY (salesman_id) REFERENCES public.users(id);


--
-- Name: purchases fk_rails_1e0d0ed652; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT fk_rails_1e0d0ed652 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: approvals fk_rails_2b2c36aa49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT fk_rails_2b2c36aa49 FOREIGN KEY (requested_by_id) REFERENCES public.users(id);


--
-- Name: replacements fk_rails_2dae84c36f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT fk_rails_2dae84c36f FOREIGN KEY (logged_by_id) REFERENCES public.users(id);


--
-- Name: dispatch_runs fk_rails_2e41cf8328; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_runs
    ADD CONSTRAINT fk_rails_2e41cf8328 FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: credit_note_lines fk_rails_34486b418c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_lines
    ADD CONSTRAINT fk_rails_34486b418c FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: brand_claims fk_rails_34cebefea8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_claims
    ADD CONSTRAINT fk_rails_34cebefea8 FOREIGN KEY (brand_id) REFERENCES public.brands(id);


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: deliveries fk_rails_3a2f0f7a8a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT fk_rails_3a2f0f7a8a FOREIGN KEY (delivered_by_id) REFERENCES public.users(id);


--
-- Name: replacements fk_rails_3d6b8867e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT fk_rails_3d6b8867e5 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders fk_rails_3dad120da9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_3dad120da9 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: customers fk_rails_4051532a6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_4051532a6f FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: credit_notes fk_rails_4117574b51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_4117574b51 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: approvals fk_rails_4d68a4583d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT fk_rails_4d68a4583d FOREIGN KEY (decided_by_id) REFERENCES public.users(id);


--
-- Name: invoices fk_rails_4fa42a6dca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_4fa42a6dca FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: credit_notes fk_rails_5cb67dee79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_5cb67dee79 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: whatsapp_messages fk_rails_5f7737729a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT fk_rails_5f7737729a FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: payment_allocations fk_rails_654fe7b556; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocations
    ADD CONSTRAINT fk_rails_654fe7b556 FOREIGN KEY (ledger_entry_id) REFERENCES public.ledger_entries(id);


--
-- Name: suppliers fk_rails_6742f066e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT fk_rails_6742f066e1 FOREIGN KEY (brand_id) REFERENCES public.brands(id);


--
-- Name: invoice_lines fk_rails_697b5c9f81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT fk_rails_697b5c9f81 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: invoices fk_rails_6e0a5814e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_6e0a5814e7 FOREIGN KEY (posted_by_id) REFERENCES public.users(id);


--
-- Name: payment_allocations fk_rails_6e77ccd439; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocations
    ADD CONSTRAINT fk_rails_6e77ccd439 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: solid_queue_batch_executions fk_rails_7c5e073422; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT fk_rails_7c5e073422 FOREIGN KEY (batch_id) REFERENCES public.solid_queue_batches(id) ON DELETE CASCADE;


--
-- Name: payments fk_rails_80fa94f8c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_80fa94f8c2 FOREIGN KEY (collected_by_id) REFERENCES public.users(id);


--
-- Name: broadcasts fk_rails_81bdaab7a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.broadcasts
    ADD CONSTRAINT fk_rails_81bdaab7a4 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: credit_notes fk_rails_83153db88d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_83153db88d FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: order_lines fk_rails_83e960fa54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines
    ADD CONSTRAINT fk_rails_83e960fa54 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: supplier_payments fk_rails_91e70c15c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_rails_91e70c15c7 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: invoice_lines fk_rails_93b334df88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT fk_rails_93b334df88 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: orders fk_rails_9ac523da23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_9ac523da23 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: deliveries fk_rails_a2a256640b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT fk_rails_a2a256640b FOREIGN KEY (dispatch_run_id) REFERENCES public.dispatch_runs(id);


--
-- Name: brand_claims fk_rails_aacea416dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_claims
    ADD CONSTRAINT fk_rails_aacea416dc FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: replacements fk_rails_ae373efcfb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT fk_rails_ae373efcfb FOREIGN KEY (brand_claim_id) REFERENCES public.brand_claims(id);


--
-- Name: ledger_entries fk_rails_ae86e9b3ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_ae86e9b3ff FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: dispatch_runs fk_rails_b158cb5470; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_runs
    ADD CONSTRAINT fk_rails_b158cb5470 FOREIGN KEY (delivery_person_id) REFERENCES public.users(id);


--
-- Name: solid_queue_batch_executions fk_rails_bc9f981155; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_batch_executions
    ADD CONSTRAINT fk_rails_bc9f981155 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: stock_movements fk_rails_c399f74509; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_c399f74509 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: deliveries fk_rails_c9bbe97b0f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT fk_rails_c9bbe97b0f FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: purchase_lines fk_rails_d16f1e6f87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_lines
    ADD CONSTRAINT fk_rails_d16f1e6f87 FOREIGN KEY (purchase_id) REFERENCES public.purchases(id);


--
-- Name: audit_events fk_rails_d27dff91d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_d27dff91d1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: replacements fk_rails_d7e610f5f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT fk_rails_d7e610f5f8 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: stock_count_lines fk_rails_d96a46556a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_lines
    ADD CONSTRAINT fk_rails_d96a46556a FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: replacements fk_rails_dc498f3c35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replacements
    ADD CONSTRAINT fk_rails_dc498f3c35 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: stock_movements fk_rails_deb37fa2ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_deb37fa2ee FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: payments fk_rails_e3a64e537e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_e3a64e537e FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: order_lines fk_rails_e6c763ee60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_lines
    ADD CONSTRAINT fk_rails_e6c763ee60 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: credit_note_lines fk_rails_eb1236e739; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_lines
    ADD CONSTRAINT fk_rails_eb1236e739 FOREIGN KEY (invoice_line_id) REFERENCES public.invoice_lines(id);


--
-- Name: payment_allocations fk_rails_f28de73578; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocations
    ADD CONSTRAINT fk_rails_f28de73578 FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: products fk_rails_f3b4d49caa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_f3b4d49caa FOREIGN KEY (brand_id) REFERENCES public.brands(id);


--
-- Name: purchases fk_rails_fd0b101ea2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT fk_rails_fd0b101ea2 FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261020100000'),
('20261020090000'),
('20261020060101'),
('20261020060100'),
('20261020060000'),
('20261020050712'),
('20261020050711');

