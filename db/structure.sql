SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ant_marine_document_release_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_document_release_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Document releases cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.document_id IS DISTINCT FROM OLD.document_id
       OR NEW.document_version_id IS DISTINCT FROM OLD.document_version_id
       OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
       OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
       OR NEW.released_at IS DISTINCT FROM OLD.released_at
       OR NEW.classification IS DISTINCT FROM OLD.classification
       OR NEW.release_kind IS DISTINCT FROM OLD.release_kind THEN
      PERFORM ant_marine_reject('Document release identity fields are immutable.');
    END IF;
    IF OLD.revoked_at IS NOT NULL
       AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
            OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason) THEN
      PERFORM ant_marine_reject('Document release revocation cannot be changed after set.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_document_version_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_document_version_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Document versions cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.document_id IS DISTINCT FROM OLD.document_id
       OR NEW.version_number IS DISTINCT FROM OLD.version_number
       OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
       OR NEW.checksum_sha256 IS DISTINCT FROM OLD.checksum_sha256
       OR NEW.filename IS DISTINCT FROM OLD.filename
       OR NEW.content_type IS DISTINCT FROM OLD.content_type
       OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
       OR NEW.uploaded_by_membership_id IS DISTINCT FROM OLD.uploaded_by_membership_id THEN
      PERFORM ant_marine_reject('Document version identity fields are immutable.');
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_inspection_evidence_link_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_inspection_evidence_link_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  insp_status text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO insp_status FROM inspections WHERE id = OLD.inspection_id;
    IF insp_status IN ('submitted', 'corrections_requested', 'completed') THEN
      PERFORM ant_marine_reject('Evidence links cannot be removed after inspection submission.');
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_inspection_template_version_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_inspection_template_version_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Inspection template versions cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.inspection_template_id IS DISTINCT FROM OLD.inspection_template_id
       OR NEW.version_number IS DISTINCT FROM OLD.version_number
       OR NEW.schema_json IS DISTINCT FROM OLD.schema_json
       OR NEW.published_at IS DISTINCT FROM OLD.published_at
       OR NEW.created_by_membership_id IS DISTINCT FROM OLD.created_by_membership_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      PERFORM ant_marine_reject('Inspection template version identity fields are immutable.');
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_invoice_line_item_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_invoice_line_item_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  parent_status text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT issue_status INTO parent_status FROM invoices WHERE id = OLD.invoice_id;
    IF parent_status IS DISTINCT FROM 'draft' THEN
      PERFORM ant_marine_reject('Invoice line items cannot be removed after issuance.');
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    SELECT issue_status INTO parent_status FROM invoices WHERE id = OLD.invoice_id;
    IF parent_status IS DISTINCT FROM 'draft' THEN
      PERFORM ant_marine_reject('Invoice line items are immutable after issuance.');
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT issue_status INTO parent_status FROM invoices WHERE id = NEW.invoice_id;
    IF parent_status IS DISTINCT FROM 'draft' THEN
      PERFORM ant_marine_reject('Invoice line items cannot be added after issuance.');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_invoice_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_invoice_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.issue_status <> 'draft' THEN
      PERFORM ant_marine_reject('Issued or void invoices cannot be deleted.');
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.issue_status IN ('issued', 'void') THEN
      IF NEW.reference_number IS DISTINCT FROM OLD.reference_number
         OR NEW.operating_organization_id IS DISTINCT FROM OLD.operating_organization_id
         OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
         OR NEW.project_id IS DISTINCT FROM OLD.project_id
         OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
         OR NEW.quote_revision_id IS DISTINCT FROM OLD.quote_revision_id
         OR NEW.quote_response_id IS DISTINCT FROM OLD.quote_response_id
         OR NEW.commercial_snapshot IS DISTINCT FROM OLD.commercial_snapshot
         OR NEW.mode IS DISTINCT FROM OLD.mode
         OR NEW.currency IS DISTINCT FROM OLD.currency
         OR NEW.total_cents IS DISTINCT FROM OLD.total_cents
         OR NEW.description IS DISTINCT FROM OLD.description
         OR NEW.billing_recipient_snapshot IS DISTINCT FROM OLD.billing_recipient_snapshot
         OR NEW.issue_on IS DISTINCT FROM OLD.issue_on
         OR NEW.due_on IS DISTINCT FROM OLD.due_on
         OR NEW.payment_terms_text IS DISTINCT FROM OLD.payment_terms_text
         OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
         OR NEW.issued_by_membership_id IS DISTINCT FROM OLD.issued_by_membership_id
         OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
         OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256
         OR NEW.created_by_membership_id IS DISTINCT FROM OLD.created_by_membership_id THEN
        PERFORM ant_marine_reject('Issued invoice financial identity fields are immutable.');
      END IF;
    END IF;

    IF OLD.issue_status = 'void' THEN
      IF NEW.voided_at IS DISTINCT FROM OLD.voided_at
         OR NEW.voided_by_membership_id IS DISTINCT FROM OLD.voided_by_membership_id
         OR NEW.void_reason IS DISTINCT FROM OLD.void_reason
         OR NEW.issue_status IS DISTINCT FROM OLD.issue_status THEN
        PERFORM ant_marine_reject('Void invoice records cannot be changed.');
      END IF;
    END IF;

    IF OLD.issue_status = 'issued' AND NEW.issue_status NOT IN ('issued', 'void') THEN
      PERFORM ant_marine_reject('Issued invoices can only move to void.');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_invoice_release_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_invoice_release_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Invoice releases cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
       OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
       OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
       OR NEW.released_at IS DISTINCT FROM OLD.released_at
       OR NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
       OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
      PERFORM ant_marine_reject('Invoice release identity fields are immutable.');
    END IF;
    IF OLD.revoked_at IS NOT NULL
       AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
            OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason
            OR NEW.revoked_by_membership_id IS DISTINCT FROM OLD.revoked_by_membership_id) THEN
      PERFORM ant_marine_reject('Invoice release revocation cannot be changed after set.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_payment_record_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_payment_record_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Payment records cannot be deleted. Record a reversal instead.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
       OR NEW.amount_cents IS DISTINCT FROM OLD.amount_cents
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.payment_on IS DISTINCT FROM OLD.payment_on
       OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
       OR NEW.external_reference IS DISTINCT FROM OLD.external_reference
       OR NEW.recorded_by_membership_id IS DISTINCT FROM OLD.recorded_by_membership_id
       OR NEW.recorded_at IS DISTINCT FROM OLD.recorded_at THEN
      PERFORM ant_marine_reject('Payment record financial fields are immutable.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_payment_reversal_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_payment_reversal_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Payment reversals cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM ant_marine_reject('Payment reversals cannot be changed.');
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_project_commercial_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_project_commercial_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.mode IS DISTINCT FROM OLD.mode
       OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
       OR NEW.quote_revision_id IS DISTINCT FROM OLD.quote_revision_id
       OR NEW.quote_response_id IS DISTINCT FROM OLD.quote_response_id
       OR NEW.quote_portal_release_id IS DISTINCT FROM OLD.quote_portal_release_id
       OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
       OR NEW.commercial_snapshot IS DISTINCT FROM OLD.commercial_snapshot THEN
      PERFORM ant_marine_reject('Project commercial source fields are immutable after creation.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_quote_line_item_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_quote_line_item_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  old_frozen boolean := false;
  new_frozen boolean := false;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    SELECT frozen_at IS NOT NULL INTO old_frozen
    FROM quote_revisions WHERE id = OLD.quote_revision_id
    FOR UPDATE;
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT frozen_at IS NOT NULL INTO new_frozen
    FROM quote_revisions WHERE id = NEW.quote_revision_id
    FOR UPDATE;
  END IF;

  IF TG_OP = 'INSERT' AND new_frozen THEN
    PERFORM ant_marine_reject('Line items cannot be added to a frozen quotation version.');
  ELSIF TG_OP = 'DELETE' AND old_frozen THEN
    PERFORM ant_marine_reject('Line items cannot be removed from a frozen quotation version.');
  ELSIF TG_OP = 'UPDATE' AND (old_frozen OR new_frozen) THEN
    PERFORM ant_marine_reject('Line items on a frozen quotation version cannot be changed.');
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_quote_response_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_quote_response_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM ant_marine_reject('Commercial decision records are append-only.');
  RETURN NULL;
END;
$$;


--
-- Name: ant_marine_quote_revision_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_quote_revision_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  allowed_status boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.frozen_at IS NOT NULL THEN
      PERFORM ant_marine_reject('Frozen quotation versions cannot be deleted.');
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.frozen_at IS NOT NULL AND NEW.frozen_at IS NULL THEN
      PERFORM ant_marine_reject('A frozen quotation version cannot be unfrozen.');
    END IF;

    IF OLD.frozen_at IS NOT NULL THEN
      allowed_status :=
        (OLD.revision_status = NEW.revision_status) OR
        (OLD.revision_status = 'approved' AND NEW.revision_status IN ('issued', 'superseded')) OR
        (OLD.revision_status = 'issued' AND NEW.revision_status = 'superseded');

      IF NOT allowed_status THEN
        PERFORM ant_marine_reject('Frozen quotation version status change is not allowed.');
      END IF;

      IF NEW.title IS DISTINCT FROM OLD.title
         OR NEW.scope_description IS DISTINCT FROM OLD.scope_description
         OR NEW.deliverables IS DISTINCT FROM OLD.deliverables
         OR NEW.exclusions IS DISTINCT FROM OLD.exclusions
         OR NEW.additional_requirements IS DISTINCT FROM OLD.additional_requirements
         OR NEW.currency IS DISTINCT FROM OLD.currency
         OR NEW.subtotal_cents IS DISTINCT FROM OLD.subtotal_cents
         OR NEW.total_cents IS DISTINCT FROM OLD.total_cents
         OR NEW.valid_until IS DISTINCT FROM OLD.valid_until
         OR NEW.payment_terms IS DISTINCT FROM OLD.payment_terms
         OR NEW.commercial_exclusions IS DISTINCT FROM OLD.commercial_exclusions
         OR NEW.additional_conditions IS DISTINCT FROM OLD.additional_conditions
         OR NEW.internal_notes IS DISTINCT FROM OLD.internal_notes
         OR NEW.recipient_snapshot IS DISTINCT FROM OLD.recipient_snapshot
         OR NEW.approved_by_membership_id IS DISTINCT FROM OLD.approved_by_membership_id
         OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
         OR NEW.prepared_by_membership_id IS DISTINCT FROM OLD.prepared_by_membership_id
         OR NEW.submitted_by_membership_id IS DISTINCT FROM OLD.submitted_by_membership_id
         OR NEW.contributor_membership_ids IS DISTINCT FROM OLD.contributor_membership_ids
         OR NEW.predecessor_revision_id IS DISTINCT FROM OLD.predecessor_revision_id
         OR NEW.revision_reason IS DISTINCT FROM OLD.revision_reason
         OR NEW.version_number IS DISTINCT FROM OLD.version_number
         OR NEW.quote_id IS DISTINCT FROM OLD.quote_id
         OR NEW.frozen_at IS DISTINCT FROM OLD.frozen_at THEN
        PERFORM ant_marine_reject('Frozen quotation commercial content cannot be changed.');
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_reject(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_reject(message text) RETURNS void
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RAISE EXCEPTION '%', message USING ERRCODE = 'integrity_constraint_violation';
      END;
      $$;


--
-- Name: ant_marine_report_release_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_report_release_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Report releases cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.report_id IS DISTINCT FROM OLD.report_id
       OR NEW.report_version_id IS DISTINCT FROM OLD.report_version_id
       OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
       OR NEW.released_by_membership_id IS DISTINCT FROM OLD.released_by_membership_id
       OR NEW.released_at IS DISTINCT FROM OLD.released_at
       OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
      PERFORM ant_marine_reject('Report release identity fields are immutable.');
    END IF;
    IF OLD.revoked_at IS NOT NULL
       AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at
            OR NEW.revocation_reason IS DISTINCT FROM OLD.revocation_reason) THEN
      PERFORM ant_marine_reject('Report release revocation cannot be changed after set.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_report_version_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_report_version_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM ant_marine_reject('Report versions cannot be deleted.');
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.report_id IS DISTINCT FROM OLD.report_id
       OR NEW.version_number IS DISTINCT FROM OLD.version_number
       OR NEW.authored_by_membership_id IS DISTINCT FROM OLD.authored_by_membership_id THEN
      PERFORM ant_marine_reject('Report version identity fields are immutable.');
    END IF;
    IF OLD.status IS DISTINCT FROM 'draft' THEN
      IF NEW.title IS DISTINCT FROM OLD.title
         OR NEW.content_json IS DISTINCT FROM OLD.content_json THEN
        PERFORM ant_marine_reject('Report version content is immutable after leaving draft.');
      END IF;
    END IF;
    IF OLD.status = 'approved' THEN
      IF NEW.storage_asset_id IS DISTINCT FROM OLD.storage_asset_id
         OR NEW.artifact_checksum_sha256 IS DISTINCT FROM OLD.artifact_checksum_sha256 THEN
        PERFORM ant_marine_reject('Approved report version artifacts are immutable.');
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: ant_marine_storage_asset_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ant_marine_storage_asset_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.scan_status IN ('available', 'rejected') THEN
      IF NEW.checksum_sha256 IS DISTINCT FROM OLD.checksum_sha256
         OR NEW.storage_key IS DISTINCT FROM OLD.storage_key
         OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
         OR NEW.content_type IS DISTINCT FROM OLD.content_type
         OR NEW.filename IS DISTINCT FROM OLD.filename
         OR NEW.active_storage_blob_id IS DISTINCT FROM OLD.active_storage_blob_id
         OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
         OR NEW.classification IS DISTINCT FROM OLD.classification
         OR NEW.encryption_key_version IS DISTINCT FROM OLD.encryption_key_version THEN
        PERFORM ant_marine_reject('Verified storage asset identity fields are immutable.');
      END IF;
    END IF;

    IF OLD.scan_status = 'available'
       AND NEW.scan_status IS DISTINCT FROM OLD.scan_status THEN
      PERFORM ant_marine_reject('Available storage assets cannot change scan status.');
    END IF;

    IF OLD.scan_status = 'rejected'
       AND NEW.scan_status = 'available' THEN
      PERFORM ant_marine_reject('Rejected storage assets cannot be marked available.');
    END IF;

    IF NEW.scan_status = 'available'
       AND (NEW.scanned_checksum_sha256 IS NULL
            OR NEW.scanned_checksum_sha256 IS DISTINCT FROM NEW.checksum_sha256) THEN
      PERFORM ant_marine_reject('Available assets require scanned checksum matching content digest.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


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
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    category character varying,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_category character varying,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT articles_status_check CHECK (((status)::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])))
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.articles_id_seq OWNED BY public.articles.id;


--
-- Name: assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignments (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL,
    membership_id bigint NOT NULL,
    assignment_kind character varying NOT NULL,
    access_scope character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    acknowledged_at timestamp(6) without time zone,
    assigned_by_membership_id bigint NOT NULL,
    reason text,
    ended_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT assignments_access_scope_check CHECK (((access_scope)::text = ANY ((ARRAY['delivery'::character varying, 'review'::character varying, 'collaborator'::character varying])::text[]))),
    CONSTRAINT assignments_kind_check CHECK (((assignment_kind)::text = ANY ((ARRAY['coordinator'::character varying, 'lead_surveyor'::character varying, 'surveyor'::character varying, 'technical_reviewer'::character varying, 'collaborator'::character varying])::text[])))
);


--
-- Name: assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assignments_id_seq OWNED BY public.assignments.id;


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    organization_id bigint,
    actor_membership_id bigint,
    event_type character varying NOT NULL,
    subject_type character varying,
    subject_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
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
-- Name: case_studies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_studies (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    service_category character varying,
    industry character varying,
    release_basis text,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_service_category character varying,
    published_industry character varying,
    published_client_challenge text,
    published_approach text,
    published_work_performed text,
    published_outcome text,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT case_studies_status_check CHECK (((status)::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])))
);


--
-- Name: case_studies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_studies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_studies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_studies_id_seq OWNED BY public.case_studies.id;


--
-- Name: client_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_contacts (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    full_name character varying NOT NULL,
    email character varying,
    phone character varying,
    job_title character varying,
    notes text,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_by_membership_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT client_contacts_name_length CHECK (((char_length((full_name)::text) >= 1) AND (char_length((full_name)::text) <= 120))),
    CONSTRAINT client_contacts_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: client_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_contacts_id_seq OWNED BY public.client_contacts.id;


--
-- Name: document_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_access_grants (
    id bigint NOT NULL,
    document_id bigint,
    project_id bigint,
    user_id bigint NOT NULL,
    granted_by_membership_id bigint NOT NULL,
    expires_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT document_access_grants_target_xor CHECK ((((document_id IS NOT NULL) AND (project_id IS NULL)) OR ((document_id IS NULL) AND (project_id IS NOT NULL))))
);


--
-- Name: document_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_access_grants_id_seq OWNED BY public.document_access_grants.id;


--
-- Name: document_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_releases (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    document_version_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    released_by_membership_id bigint NOT NULL,
    released_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    revocation_reason text,
    classification character varying DEFAULT 'standard'::character varying NOT NULL,
    release_kind character varying DEFAULT 'client_share'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT document_releases_classification_check CHECK (((classification)::text = ANY ((ARRAY['standard'::character varying, 'confidential'::character varying])::text[]))),
    CONSTRAINT document_releases_release_kind_check CHECK (((release_kind)::text = 'client_share'::text))
);


--
-- Name: document_releases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_releases_id_seq OWNED BY public.document_releases.id;


--
-- Name: document_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_reviews (
    id bigint NOT NULL,
    document_version_id bigint NOT NULL,
    reviewer_membership_id bigint NOT NULL,
    outcome character varying,
    comments text,
    decided_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT document_reviews_open_or_decided_check CHECK ((((outcome IS NULL) AND (decided_at IS NULL)) OR ((outcome IS NOT NULL) AND (decided_at IS NOT NULL)))),
    CONSTRAINT document_reviews_outcome_check CHECK (((outcome IS NULL) OR ((outcome)::text = ANY ((ARRAY['approved'::character varying, 'changes_requested'::character varying])::text[]))))
);


--
-- Name: document_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_reviews_id_seq OWNED BY public.document_reviews.id;


--
-- Name: document_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_versions (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    version_number integer NOT NULL,
    storage_asset_id bigint NOT NULL,
    filename character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum_sha256 character varying NOT NULL,
    uploaded_by_membership_id bigint NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT document_versions_byte_size_positive CHECK ((byte_size > 0))
);


--
-- Name: document_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_versions_id_seq OWNED BY public.document_versions.id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    project_id bigint NOT NULL,
    title character varying NOT NULL,
    category character varying NOT NULL,
    classification character varying DEFAULT 'standard'::character varying NOT NULL,
    visibility_intent character varying DEFAULT 'internal'::character varying NOT NULL,
    workflow_status character varying DEFAULT 'working_draft'::character varying NOT NULL,
    current_version_id bigint,
    upload_request_id bigint,
    created_by_membership_id bigint NOT NULL,
    description text,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT documents_classification_check CHECK (((classification)::text = ANY ((ARRAY['standard'::character varying, 'confidential'::character varying])::text[]))),
    CONSTRAINT documents_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200))),
    CONSTRAINT documents_visibility_intent_check CHECK (((visibility_intent)::text = ANY ((ARRAY['internal'::character varying, 'client_submitted'::character varying, 'for_client_release'::character varying])::text[]))),
    CONSTRAINT documents_workflow_status_check CHECK (((workflow_status)::text = ANY ((ARRAY['working_draft'::character varying, 'submitted'::character varying, 'changes_requested'::character varying, 'approved'::character varying, 'released'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: inspection_checklist_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspection_checklist_responses (
    id bigint NOT NULL,
    inspection_id bigint NOT NULL,
    item_key character varying NOT NULL,
    response_type character varying NOT NULL,
    value_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    not_applicable_reason text,
    updated_by_membership_id bigint NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inspection_checklist_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspection_checklist_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_checklist_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspection_checklist_responses_id_seq OWNED BY public.inspection_checklist_responses.id;


--
-- Name: inspection_evidence_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspection_evidence_links (
    id bigint NOT NULL,
    inspection_id bigint NOT NULL,
    document_version_id bigint NOT NULL,
    finding_id bigint,
    checklist_item_key character varying,
    attached_by_membership_id bigint NOT NULL,
    attached_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inspection_evidence_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspection_evidence_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_evidence_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspection_evidence_links_id_seq OWNED BY public.inspection_evidence_links.id;


--
-- Name: inspection_findings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspection_findings (
    id bigint NOT NULL,
    inspection_id bigint NOT NULL,
    reference_number character varying NOT NULL,
    checklist_item_key character varying,
    title character varying NOT NULL,
    observation text NOT NULL,
    recommendation text,
    location_or_equipment character varying,
    classification character varying DEFAULT 'observation'::character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    recorded_by_membership_id bigint NOT NULL,
    recorded_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT inspection_findings_classification_check CHECK (((classification)::text = ANY ((ARRAY['observation'::character varying, 'deficiency'::character varying, 'recommendation'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT inspection_findings_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'recorded'::character varying, 'included_in_report'::character varying])::text[])))
);


--
-- Name: inspection_findings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspection_findings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_findings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspection_findings_id_seq OWNED BY public.inspection_findings.id;


--
-- Name: inspection_template_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspection_template_versions (
    id bigint NOT NULL,
    inspection_template_id bigint NOT NULL,
    version_number integer NOT NULL,
    schema_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    published_at timestamp(6) without time zone,
    created_by_membership_id bigint NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: inspection_template_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspection_template_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_template_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspection_template_versions_id_seq OWNED BY public.inspection_template_versions.id;


--
-- Name: inspection_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspection_templates (
    id bigint NOT NULL,
    operating_organization_id bigint NOT NULL,
    key character varying NOT NULL,
    title character varying NOT NULL,
    description text,
    service_id bigint,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    current_version_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT inspection_templates_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT inspection_templates_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: inspection_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspection_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspection_templates_id_seq OWNED BY public.inspection_templates.id;


--
-- Name: inspections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspections (
    id bigint NOT NULL,
    reference_number character varying NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    project_id bigint NOT NULL,
    service_id bigint,
    inspection_template_version_id bigint NOT NULL,
    schedule_event_id bigint,
    title character varying NOT NULL,
    inspection_type character varying NOT NULL,
    vessel_name character varying,
    location character varying,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    assigned_surveyor_membership_id bigint,
    created_by_membership_id bigint NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    operational_instructions text,
    submitted_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    cancelled_at timestamp(6) without time zone,
    cancellation_reason text,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT inspections_mode_check CHECK (((mode)::text = 'simulated'::text)),
    CONSTRAINT inspections_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'assigned'::character varying, 'in_progress'::character varying, 'submitted'::character varying, 'corrections_requested'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT inspections_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: inspections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inspections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inspections_id_seq OWNED BY public.inspections.id;


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    email character varying NOT NULL,
    role_key character varying NOT NULL,
    token_digest character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    invited_by_membership_id bigint NOT NULL,
    accepted_by_user_id bigint,
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invitations_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('accepted'::character varying)::text, ('revoked'::character varying)::text, ('expired'::character varying)::text])))
);


--
-- Name: invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitations_id_seq OWNED BY public.invitations.id;


--
-- Name: invoice_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_line_items (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    description text NOT NULL,
    quantity numeric(12,3) DEFAULT 1.0 NOT NULL,
    unit character varying DEFAULT 'Lot'::character varying NOT NULL,
    unit_amount_cents bigint NOT NULL,
    line_total_cents bigint NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    quote_line_item_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invoice_line_items_line_total_check CHECK ((line_total_cents >= 0)),
    CONSTRAINT invoice_line_items_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT invoice_line_items_unit_amount_check CHECK ((unit_amount_cents >= 0))
);


--
-- Name: invoice_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoice_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoice_line_items_id_seq OWNED BY public.invoice_line_items.id;


--
-- Name: invoice_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_releases (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    released_by_membership_id bigint NOT NULL,
    released_at timestamp(6) without time zone NOT NULL,
    storage_asset_id bigint NOT NULL,
    artifact_checksum_sha256 character varying NOT NULL,
    revoked_at timestamp(6) without time zone,
    revoked_by_membership_id bigint,
    revocation_reason text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invoice_releases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoice_releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoice_releases_id_seq OWNED BY public.invoice_releases.id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id bigint NOT NULL,
    reference_number character varying NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    project_id bigint NOT NULL,
    quote_id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    quote_response_id bigint NOT NULL,
    commercial_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    issue_status character varying DEFAULT 'draft'::character varying NOT NULL,
    currency character varying NOT NULL,
    total_cents bigint DEFAULT 0 NOT NULL,
    description text,
    billing_recipient_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    issue_on date,
    due_on date,
    payment_terms_text text,
    issued_at timestamp(6) without time zone,
    issued_by_membership_id bigint,
    voided_at timestamp(6) without time zone,
    voided_by_membership_id bigint,
    void_reason text,
    storage_asset_id bigint,
    artifact_checksum_sha256 character varying,
    created_by_membership_id bigint NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invoices_currency_check CHECK (((currency)::text = ANY ((ARRAY['GHS'::character varying, 'USD'::character varying, 'EUR'::character varying, 'GBP'::character varying])::text[]))),
    CONSTRAINT invoices_issue_status_check CHECK (((issue_status)::text = ANY ((ARRAY['draft'::character varying, 'issued'::character varying, 'void'::character varying])::text[]))),
    CONSTRAINT invoices_mode_check CHECK (((mode)::text = 'simulated'::text)),
    CONSTRAINT invoices_total_cents_check CHECK ((total_cents >= 0))
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
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    role_key character varying NOT NULL,
    status character varying DEFAULT 'invited'::character varying NOT NULL,
    permission_epoch integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    invited_at timestamp(6) without time zone,
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT memberships_status_check CHECK (((status)::text = ANY ((ARRAY['invited'::character varying, 'active'::character varying, 'suspended'::character varying, 'removed'::character varying])::text[])))
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    profile jsonb,
    settings jsonb,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reference_number character varying,
    CONSTRAINT organizations_kind_check CHECK (((kind)::text = ANY ((ARRAY['ant_marine'::character varying, 'client'::character varying])::text[]))),
    CONSTRAINT organizations_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: payment_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_records (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    amount_cents bigint NOT NULL,
    currency character varying NOT NULL,
    payment_on date NOT NULL,
    payment_method character varying NOT NULL,
    external_reference character varying,
    internal_note text,
    recorded_by_membership_id bigint NOT NULL,
    recorded_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payment_records_amount_check CHECK ((amount_cents > 0)),
    CONSTRAINT payment_records_currency_check CHECK (((currency)::text = ANY ((ARRAY['GHS'::character varying, 'USD'::character varying, 'EUR'::character varying, 'GBP'::character varying])::text[])))
);


--
-- Name: payment_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_records_id_seq OWNED BY public.payment_records.id;


--
-- Name: payment_reversals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_reversals (
    id bigint NOT NULL,
    payment_record_id bigint NOT NULL,
    amount_cents bigint NOT NULL,
    reason text NOT NULL,
    recorded_by_membership_id bigint NOT NULL,
    recorded_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payment_reversals_amount_check CHECK ((amount_cents > 0))
);


--
-- Name: payment_reversals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_reversals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_reversals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_reversals_id_seq OWNED BY public.payment_reversals.id;


--
-- Name: permission_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_overrides (
    id bigint NOT NULL,
    membership_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    effect character varying NOT NULL,
    granted_by_membership_id bigint NOT NULL,
    reason text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT permission_overrides_effect_check CHECK (((effect)::text = ANY (ARRAY[('allow'::character varying)::text, ('deny'::character varying)::text])))
);


--
-- Name: permission_overrides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permission_overrides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permission_overrides_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permission_overrides_id_seq OWNED BY public.permission_overrides.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    key character varying NOT NULL,
    display_name character varying NOT NULL,
    description text,
    category character varying NOT NULL,
    domain character varying NOT NULL,
    override_rule character varying DEFAULT 'yes'::character varying NOT NULL,
    catalogue_version integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT permissions_override_rule_check CHECK (((override_rule)::text = ANY (ARRAY[('yes'::character varying)::text, ('protected'::character varying)::text, ('deny_only'::character varying)::text])))
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: project_milestones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_milestones (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    kind character varying DEFAULT 'operational'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    responsible_membership_id bigint,
    target_on date,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    completed_at timestamp(6) without time zone,
    completed_by_membership_id bigint,
    counts_toward_progress boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT project_milestones_kind_check CHECK (((kind)::text = ANY ((ARRAY['project_initiated'::character varying, 'planning'::character varying, 'mobilization'::character varying, 'site_work'::character varying, 'technical_review'::character varying, 'report_release'::character varying, 'project_completion'::character varying, 'operational'::character varying])::text[]))),
    CONSTRAINT project_milestones_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: project_milestones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_milestones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_milestones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_milestones_id_seq OWNED BY public.project_milestones.id;


--
-- Name: project_status_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_status_events (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    from_status character varying,
    to_status character varying NOT NULL,
    actor_membership_id bigint NOT NULL,
    reason text,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: project_status_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_status_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_status_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_status_events_id_seq OWNED BY public.project_status_events.id;


--
-- Name: project_updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_updates (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    author_membership_id bigint NOT NULL,
    body text NOT NULL,
    visibility character varying DEFAULT 'client'::character varying NOT NULL,
    published_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT project_updates_body_length CHECK (((char_length(body) >= 1) AND (char_length(body) <= 5000))),
    CONSTRAINT project_updates_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['client'::character varying, 'internal'::character varying])::text[])))
);


--
-- Name: project_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_updates_id_seq OWNED BY public.project_updates.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    reference_number character varying NOT NULL,
    title character varying NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    service_id bigint,
    service_inquiry_id bigint,
    quote_id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    quote_response_id bigint NOT NULL,
    quote_portal_release_id bigint NOT NULL,
    created_by_membership_id bigint NOT NULL,
    coordinator_membership_id bigint,
    internal_status character varying DEFAULT 'planning'::character varying NOT NULL,
    client_status character varying DEFAULT 'planning'::character varying NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    location character varying,
    vessel_name character varying,
    vessel_identifier character varying,
    operational_description text,
    internal_notes text,
    proposed_start_on date,
    target_completion_on date,
    commercial_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT projects_client_status_check CHECK (((client_status)::text = ANY ((ARRAY['planning'::character varying, 'scheduled'::character varying, 'in_progress'::character varying, 'on_hold'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT projects_internal_status_check CHECK (((internal_status)::text = ANY ((ARRAY['planning'::character varying, 'scheduled'::character varying, 'in_progress'::character varying, 'technical_review'::character varying, 'report_ready'::character varying, 'completed'::character varying, 'closed'::character varying, 'on_hold'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT projects_mode_check CHECK (((mode)::text = 'simulated'::text)),
    CONSTRAINT projects_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: public_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_resources (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    resource_category character varying,
    related_content_label character varying,
    file_release_enabled boolean DEFAULT false NOT NULL,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_resource_category character varying,
    published_related_content_label character varying,
    published_file_release_enabled boolean DEFAULT false NOT NULL,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT public_resources_status_check CHECK (((status)::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])))
);


--
-- Name: public_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.public_resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: public_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.public_resources_id_seq OWNED BY public.public_resources.id;


--
-- Name: public_site_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_site_pages (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    page_key character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    page_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_page_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT public_site_pages_page_key_check CHECK (((page_key)::text = ANY ((ARRAY['homepage'::character varying, 'about'::character varying, 'industries'::character varying, 'how_we_work'::character varying, 'contact'::character varying])::text[]))),
    CONSTRAINT public_site_pages_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: public_site_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.public_site_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: public_site_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.public_site_pages_id_seq OWNED BY public.public_site_pages.id;


--
-- Name: quote_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_deliveries (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    quote_id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    requested_by_membership_id bigint NOT NULL,
    dispatched_by_membership_id bigint,
    channel character varying DEFAULT 'email'::character varying NOT NULL,
    status character varying DEFAULT 'prepared'::character varying NOT NULL,
    delivery_adapter character varying NOT NULL,
    idempotency_key character varying NOT NULL,
    recipient_email character varying NOT NULL,
    recipient_name character varying,
    recipient_company character varying,
    attempt_count integer DEFAULT 0 NOT NULL,
    prepared_at timestamp(6) without time zone NOT NULL,
    queued_at timestamp(6) without time zone,
    attempted_at timestamp(6) without time zone,
    accepted_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    confirmed_at timestamp(6) without time zone,
    cancelled_at timestamp(6) without time zone,
    provider_message_id character varying,
    provider_response character varying,
    failure_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT quote_deliveries_accepted_has_timestamp CHECK ((((status)::text <> 'accepted_by_provider'::text) OR (accepted_at IS NOT NULL))),
    CONSTRAINT quote_deliveries_channel_check CHECK (((channel)::text = 'email'::text)),
    CONSTRAINT quote_deliveries_confirmation_needs_evidence CHECK ((((status)::text <> 'delivery_confirmed'::text) OR ((confirmed_at IS NOT NULL) AND (provider_message_id IS NOT NULL)))),
    CONSTRAINT quote_deliveries_status_check CHECK (((status)::text = ANY ((ARRAY['prepared'::character varying, 'queued'::character varying, 'sending'::character varying, 'accepted_by_provider'::character varying, 'failed'::character varying, 'outcome_unknown'::character varying, 'delivery_confirmed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: quote_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_deliveries_id_seq OWNED BY public.quote_deliveries.id;


--
-- Name: quote_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_line_items (
    id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    description character varying NOT NULL,
    quantity numeric(12,3) DEFAULT 1.0 NOT NULL,
    unit character varying DEFAULT 'each'::character varying NOT NULL,
    unit_price_cents bigint DEFAULT 0 NOT NULL,
    line_total_cents bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT quote_line_items_amounts_non_negative CHECK (((unit_price_cents >= 0) AND (line_total_cents >= 0))),
    CONSTRAINT quote_line_items_quantity_positive CHECK ((quantity > (0)::numeric))
);


--
-- Name: quote_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_line_items_id_seq OWNED BY public.quote_line_items.id;


--
-- Name: quote_portal_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_portal_releases (
    id bigint NOT NULL,
    quote_id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    released_by_membership_id bigint NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    released_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    revoked_by_membership_id bigint,
    label character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT quote_portal_releases_mode_check CHECK (((mode)::text = 'simulated'::text))
);


--
-- Name: quote_portal_releases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_portal_releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_portal_releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_portal_releases_id_seq OWNED BY public.quote_portal_releases.id;


--
-- Name: quote_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_responses (
    id bigint NOT NULL,
    quote_id bigint NOT NULL,
    quote_revision_id bigint NOT NULL,
    quote_portal_release_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    responded_by_membership_id bigint NOT NULL,
    responded_by_user_id bigint NOT NULL,
    response character varying NOT NULL,
    reason text,
    confirmed_at timestamp(6) without time zone NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    idempotency_key character varying NOT NULL,
    offer_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    confirmation_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT quote_responses_changes_require_reason CHECK ((((response)::text <> 'changes_requested'::text) OR ((reason IS NOT NULL) AND (char_length(btrim(reason)) > 0)))),
    CONSTRAINT quote_responses_decline_requires_reason CHECK ((((response)::text <> 'declined'::text) OR ((reason IS NOT NULL) AND (char_length(btrim(reason)) > 0)))),
    CONSTRAINT quote_responses_mode_check CHECK (((mode)::text = 'simulated'::text)),
    CONSTRAINT quote_responses_response_check CHECK (((response)::text = ANY ((ARRAY['accepted'::character varying, 'declined'::character varying, 'changes_requested'::character varying])::text[])))
);


--
-- Name: quote_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_responses_id_seq OWNED BY public.quote_responses.id;


--
-- Name: quote_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_revisions (
    id bigint NOT NULL,
    quote_id bigint NOT NULL,
    version_number integer NOT NULL,
    revision_status character varying DEFAULT 'draft'::character varying NOT NULL,
    title character varying,
    scope_description text,
    deliverables text,
    exclusions text,
    additional_requirements text,
    currency character varying DEFAULT 'GHS'::character varying NOT NULL,
    subtotal_cents bigint DEFAULT 0 NOT NULL,
    total_cents bigint DEFAULT 0 NOT NULL,
    valid_until date,
    payment_terms text,
    commercial_exclusions text,
    additional_conditions text,
    internal_notes text,
    recipient_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    frozen_at timestamp(6) without time zone,
    approved_by_membership_id bigint,
    approved_at timestamp(6) without time zone,
    issued_by_membership_id bigint,
    issued_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    prepared_by_membership_id bigint,
    submitted_by_membership_id bigint,
    contributor_membership_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    predecessor_revision_id bigint,
    superseded_by_revision_id bigint,
    revision_reason text,
    superseded_at timestamp(6) without time zone,
    CONSTRAINT quote_revisions_approved_are_frozen CHECK ((((revision_status)::text <> ALL ((ARRAY['approved'::character varying, 'issued'::character varying])::text[])) OR (frozen_at IS NOT NULL))),
    CONSTRAINT quote_revisions_approver_is_independent CHECK (((approved_by_membership_id IS NULL) OR ((approved_by_membership_id IS DISTINCT FROM prepared_by_membership_id) AND (approved_by_membership_id IS DISTINCT FROM submitted_by_membership_id) AND (NOT (approved_by_membership_id = ANY (contributor_membership_ids)))))),
    CONSTRAINT quote_revisions_currency_check CHECK (((currency)::text = ANY ((ARRAY['GHS'::character varying, 'USD'::character varying, 'EUR'::character varying, 'GBP'::character varying])::text[]))),
    CONSTRAINT quote_revisions_later_versions_have_lineage CHECK (((version_number = 1) OR ((predecessor_revision_id IS NOT NULL) AND (revision_reason IS NOT NULL)))),
    CONSTRAINT quote_revisions_reason_length CHECK (((revision_reason IS NULL) OR (char_length(revision_reason) <= 500))),
    CONSTRAINT quote_revisions_status_check CHECK (((revision_status)::text = ANY ((ARRAY['draft'::character varying, 'pending_review'::character varying, 'approved'::character varying, 'issued'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT quote_revisions_superseded_have_timestamp CHECK ((((revision_status)::text <> 'superseded'::text) OR (superseded_at IS NOT NULL))),
    CONSTRAINT quote_revisions_totals_non_negative CHECK (((subtotal_cents >= 0) AND (total_cents >= 0)))
);


--
-- Name: quote_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_revisions_id_seq OWNED BY public.quote_revisions.id;


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotes (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    client_organization_id bigint,
    service_id bigint,
    reference_number character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    delivery_state character varying DEFAULT 'not_prepared'::character varying NOT NULL,
    prospective_client jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_revision_id bigint,
    service_inquiry_id bigint,
    CONSTRAINT quotes_delivery_state_check CHECK (((delivery_state)::text = ANY ((ARRAY['not_prepared'::character varying, 'prepared'::character varying, 'delivery_pending'::character varying, 'delivery_attempted'::character varying, 'delivered'::character varying, 'delivery_failed'::character varying])::text[]))),
    CONSTRAINT quotes_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending_review'::character varying, 'returned_for_correction'::character varying, 'approved_for_issuance'::character varying, 'issued'::character varying, 'withdrawn'::character varying, 'superseded'::character varying])::text[])))
);


--
-- Name: quotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quotes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quotes_id_seq OWNED BY public.quotes.id;


--
-- Name: report_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_releases (
    id bigint NOT NULL,
    report_id bigint NOT NULL,
    report_version_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    released_by_membership_id bigint NOT NULL,
    released_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    revocation_reason text,
    artifact_checksum_sha256 character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: report_releases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_releases_id_seq OWNED BY public.report_releases.id;


--
-- Name: report_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_reviews (
    id bigint NOT NULL,
    report_version_id bigint NOT NULL,
    reviewer_membership_id bigint NOT NULL,
    outcome character varying NOT NULL,
    comments text,
    decided_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT report_reviews_outcome_check CHECK (((outcome)::text = ANY ((ARRAY['approved'::character varying, 'changes_requested'::character varying])::text[])))
);


--
-- Name: report_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_reviews_id_seq OWNED BY public.report_reviews.id;


--
-- Name: report_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_versions (
    id bigint NOT NULL,
    report_id bigint NOT NULL,
    version_number integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    title character varying NOT NULL,
    content_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    authored_by_membership_id bigint NOT NULL,
    submitted_by_membership_id bigint,
    storage_asset_id bigint,
    artifact_checksum_sha256 character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT report_versions_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted_for_review'::character varying, 'changes_requested'::character varying, 'approved'::character varying])::text[])))
);


--
-- Name: report_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_versions_id_seq OWNED BY public.report_versions.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id bigint NOT NULL,
    reference_number character varying NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    project_id bigint NOT NULL,
    inspection_id bigint,
    title character varying NOT NULL,
    report_kind character varying DEFAULT 'technical_report'::character varying NOT NULL,
    mode character varying DEFAULT 'simulated'::character varying NOT NULL,
    current_version_id bigint,
    created_by_membership_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT reports_mode_check CHECK (((mode)::text = 'simulated'::text)),
    CONSTRAINT reports_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id bigint NOT NULL,
    role_key character varying NOT NULL,
    permission_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.role_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.role_permissions_id_seq OWNED BY public.role_permissions.id;


--
-- Name: schedule_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_events (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    title character varying NOT NULL,
    activity_type character varying DEFAULT 'site_work'::character varying NOT NULL,
    confirmation_state character varying DEFAULT 'proposed'::character varying NOT NULL,
    location character varying,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    responsible_membership_id bigint,
    internal_notes text,
    cancellation_reason text,
    created_by_membership_id bigint NOT NULL,
    confirmed_by_membership_id bigint,
    confirmed_at timestamp(6) without time zone,
    conflict_override boolean DEFAULT false NOT NULL,
    conflict_override_reason text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT schedule_events_activity_type_check CHECK (((activity_type)::text = ANY ((ARRAY['site_work'::character varying, 'mobilization'::character varying, 'meeting'::character varying, 'inspection'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT schedule_events_confirmation_state_check CHECK (((confirmation_state)::text = ANY ((ARRAY['proposed'::character varying, 'confirmed'::character varying, 'rescheduled'::character varying, 'cancelled'::character varying, 'completed'::character varying])::text[]))),
    CONSTRAINT schedule_events_time_order_check CHECK ((starts_at < ends_at))
);


--
-- Name: schedule_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schedule_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schedule_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schedule_events_id_seq OWNED BY public.schedule_events.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: service_inquiries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_inquiries (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    client_organization_id bigint,
    service_id bigint,
    reference_number character varying NOT NULL,
    channel character varying DEFAULT 'public_form'::character varying NOT NULL,
    current_status character varying DEFAULT 'submitted'::character varying NOT NULL,
    service_title_snapshot character varying,
    company_name character varying NOT NULL,
    contact_name character varying NOT NULL,
    contact_email character varying NOT NULL,
    contact_phone character varying,
    project_name character varying,
    vessel_name character varying,
    location character varying NOT NULL,
    description text NOT NULL,
    preferred_date date,
    submission_token character varying NOT NULL,
    submission_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    submitted_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    assigned_membership_id bigint,
    duplicate_of_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    review_started_at timestamp(6) without time zone,
    qualified_at timestamp(6) without time zone,
    qualification_note text,
    closure_reason character varying,
    closure_note text,
    closed_at timestamp(6) without time zone,
    CONSTRAINT service_inquiries_channel_check CHECK (((channel)::text = ANY ((ARRAY['public_form'::character varying, 'contact_form'::character varying, 'client_portal'::character varying, 'staff'::character varying])::text[]))),
    CONSTRAINT service_inquiries_closed_reason_matches CHECK ((((current_status)::text <> 'closed'::text) OR ((closure_reason)::text = ANY ((ARRAY['cancelled'::character varying, 'not_proceeding'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT service_inquiries_closed_states_have_reason CHECK ((((current_status)::text = ANY ((ARRAY['closed'::character varying, 'unqualified'::character varying, 'merged'::character varying])::text[])) = ((closure_reason IS NOT NULL) AND (closed_at IS NOT NULL)))),
    CONSTRAINT service_inquiries_closure_reason_check CHECK (((closure_reason IS NULL) OR ((closure_reason)::text = ANY ((ARRAY['cancelled'::character varying, 'not_proceeding'::character varying, 'other'::character varying, 'outside_scope'::character varying, 'duplicate'::character varying])::text[])))),
    CONSTRAINT service_inquiries_length_check CHECK (((char_length(description) <= 4000) AND (char_length((company_name)::text) <= 160) AND (char_length((contact_name)::text) <= 120) AND (char_length((contact_email)::text) <= 254) AND (char_length((location)::text) <= 200))),
    CONSTRAINT service_inquiries_merged_has_canonical CHECK ((((current_status)::text <> 'merged'::text) OR (((closure_reason)::text = 'duplicate'::text) AND (duplicate_of_id IS NOT NULL) AND (duplicate_of_id <> id)))),
    CONSTRAINT service_inquiries_other_reason_has_note CHECK ((((closure_reason)::text IS DISTINCT FROM 'other'::text) OR (closure_note IS NOT NULL))),
    CONSTRAINT service_inquiries_status_check CHECK (((current_status)::text = ANY ((ARRAY['submitted'::character varying, 'under_review'::character varying, 'needs_clarification'::character varying, 'qualified'::character varying, 'unqualified'::character varying, 'merged'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT service_inquiries_triage_note_length CHECK (((char_length(COALESCE(qualification_note, ''::text)) <= 2000) AND (char_length(COALESCE(closure_note, ''::text)) <= 2000))),
    CONSTRAINT service_inquiries_unqualified_has_note CHECK ((((current_status)::text <> 'unqualified'::text) OR (((closure_reason)::text = 'outside_scope'::text) AND (closure_note IS NOT NULL))))
);


--
-- Name: service_inquiries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_inquiries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_inquiries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_inquiries_id_seq OWNED BY public.service_inquiries.id;


--
-- Name: service_inquiry_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_inquiry_assignments (
    id bigint NOT NULL,
    service_inquiry_id bigint NOT NULL,
    previous_membership_id bigint,
    new_membership_id bigint,
    actor_membership_id bigint NOT NULL,
    reason text,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT service_inquiry_assignments_change_check CHECK ((previous_membership_id IS DISTINCT FROM new_membership_id)),
    CONSTRAINT service_inquiry_assignments_reason_length CHECK (((reason IS NULL) OR (char_length(reason) <= 500)))
);


--
-- Name: service_inquiry_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_inquiry_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_inquiry_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_inquiry_assignments_id_seq OWNED BY public.service_inquiry_assignments.id;


--
-- Name: service_inquiry_clarifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_inquiry_clarifications (
    id bigint NOT NULL,
    service_inquiry_id bigint NOT NULL,
    created_by_membership_id bigint NOT NULL,
    subject character varying NOT NULL,
    questions text NOT NULL,
    prepared_message text,
    status character varying DEFAULT 'prepared'::character varying NOT NULL,
    contact_channel character varying,
    contacted_at timestamp(6) without time zone,
    contacted_by_membership_id bigint,
    response_text text,
    response_source character varying,
    response_received_at timestamp(6) without time zone,
    response_recorded_by_membership_id bigint,
    withdrawn_at timestamp(6) without time zone,
    withdrawn_by_membership_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT service_inquiry_clarifications_answer_recorded CHECK ((((status)::text <> 'answered'::text) OR ((response_text IS NOT NULL) AND (response_source IS NOT NULL) AND (response_received_at IS NOT NULL) AND (response_recorded_by_membership_id IS NOT NULL)))),
    CONSTRAINT service_inquiry_clarifications_channel_check CHECK (((contact_channel IS NULL) OR ((contact_channel)::text = ANY ((ARRAY['phone'::character varying, 'email_outside_system'::character varying, 'in_person'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT service_inquiry_clarifications_contact_recorded CHECK ((((status)::text <> 'contacted_outside_system'::text) OR ((contact_channel IS NOT NULL) AND (contacted_at IS NOT NULL) AND (contacted_by_membership_id IS NOT NULL)))),
    CONSTRAINT service_inquiry_clarifications_length_check CHECK (((char_length((subject)::text) <= 160) AND (char_length(questions) <= 2000) AND (char_length(COALESCE(prepared_message, ''::text)) <= 4000) AND (char_length(COALESCE(response_text, ''::text)) <= 4000))),
    CONSTRAINT service_inquiry_clarifications_source_check CHECK (((response_source IS NULL) OR ((response_source)::text = ANY ((ARRAY['phone'::character varying, 'email'::character varying, 'in_person'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT service_inquiry_clarifications_status_check CHECK (((status)::text = ANY ((ARRAY['prepared'::character varying, 'contacted_outside_system'::character varying, 'answered'::character varying, 'withdrawn'::character varying])::text[]))),
    CONSTRAINT service_inquiry_clarifications_withdrawal_recorded CHECK ((((status)::text <> 'withdrawn'::text) OR ((withdrawn_at IS NOT NULL) AND (withdrawn_by_membership_id IS NOT NULL))))
);


--
-- Name: service_inquiry_clarifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_inquiry_clarifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_inquiry_clarifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_inquiry_clarifications_id_seq OWNED BY public.service_inquiry_clarifications.id;


--
-- Name: service_inquiry_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_inquiry_notes (
    id bigint NOT NULL,
    service_inquiry_id bigint NOT NULL,
    author_membership_id bigint NOT NULL,
    corrects_note_id bigint,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT service_inquiry_notes_body_check CHECK (((char_length(btrim(body)) > 0) AND (char_length(body) <= 4000)))
);


--
-- Name: service_inquiry_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_inquiry_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_inquiry_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_inquiry_notes_id_seq OWNED BY public.service_inquiry_notes.id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    category character varying,
    audience text,
    scope_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    process_steps jsonb DEFAULT '[]'::jsonb NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    icon_key character varying,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_audience text,
    published_scope_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    published_process_steps jsonb DEFAULT '[]'::jsonb NOT NULL,
    published_display_order integer,
    published_icon_key character varying,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT services_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    membership_id bigint,
    ip_address character varying,
    user_agent character varying,
    security_version_at_issue integer DEFAULT 0 NOT NULL,
    revoked_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone NOT NULL,
    last_active_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    permission_epoch_at_issue integer DEFAULT 0 NOT NULL
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
-- Name: staff_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_notifications (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    recipient_membership_id bigint NOT NULL,
    audit_event_id bigint NOT NULL,
    kind character varying NOT NULL,
    subject_type character varying NOT NULL,
    subject_id bigint NOT NULL,
    title character varying NOT NULL,
    dedupe_key character varying NOT NULL,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT staff_notifications_kind_check CHECK (((kind)::text = ANY ((ARRAY['new_enquiry'::character varying, 'enquiry_assigned'::character varying, 'enquiry_reassigned_away'::character varying, 'clarification_answered'::character varying, 'quote_accepted'::character varying, 'quote_declined'::character varying, 'quote_changes_requested'::character varying, 'project_created'::character varying, 'project_assigned'::character varying, 'project_assignment_changed'::character varying, 'task_assigned'::character varying, 'schedule_confirmed'::character varying, 'schedule_cancelled'::character varying, 'project_update'::character varying, 'document_uploaded'::character varying, 'document_review_required'::character varying, 'document_changes_requested'::character varying, 'document_approved'::character varying, 'document_released'::character varying, 'document_release_revoked'::character varying, 'upload_requested'::character varying, 'inspection_assigned'::character varying, 'inspection_submitted'::character varying, 'report_review_required'::character varying, 'report_changes_requested'::character varying, 'report_approved'::character varying, 'report_released'::character varying, 'invoice_issued'::character varying, 'invoice_released'::character varying, 'payment_recorded'::character varying, 'payment_reversed'::character varying, 'invoice_voided'::character varying])::text[]))),
    CONSTRAINT staff_notifications_title_length CHECK ((char_length((title)::text) <= 200))
);


--
-- Name: staff_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_notifications_id_seq OWNED BY public.staff_notifications.id;


--
-- Name: storage_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_assets (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    uploaded_by_membership_id bigint NOT NULL,
    scan_status character varying DEFAULT 'pending_upload'::character varying NOT NULL,
    classification character varying DEFAULT 'standard'::character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum_sha256 character varying NOT NULL,
    storage_key character varying NOT NULL,
    encryption_key_version integer NOT NULL,
    active_storage_blob_id bigint,
    scan_result character varying,
    scanned_at timestamp(6) without time zone,
    rejected_reason character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    scanned_checksum_sha256 character varying,
    scanner_adapter character varying,
    CONSTRAINT storage_assets_available_requires_scanned_checksum CHECK ((((scan_status)::text <> 'available'::text) OR ((scanned_checksum_sha256 IS NOT NULL) AND ((scanned_checksum_sha256)::text = (checksum_sha256)::text)))),
    CONSTRAINT storage_assets_classification_check CHECK (((classification)::text = ANY ((ARRAY['standard'::character varying, 'confidential'::character varying])::text[]))),
    CONSTRAINT storage_assets_scan_status_check CHECK (((scan_status)::text = ANY ((ARRAY['pending_upload'::character varying, 'scanning'::character varying, 'available'::character varying, 'rejected'::character varying])::text[])))
);


--
-- Name: storage_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.storage_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: storage_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.storage_assets_id_seq OWNED BY public.storage_assets.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    assignee_membership_id bigint,
    priority character varying DEFAULT 'normal'::character varying NOT NULL,
    status character varying DEFAULT 'todo'::character varying NOT NULL,
    due_on date,
    completed_at timestamp(6) without time zone,
    created_by_membership_id bigint NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT tasks_priority_check CHECK (((priority)::text = ANY ((ARRAY['low'::character varying, 'normal'::character varying, 'high'::character varying, 'urgent'::character varying])::text[]))),
    CONSTRAINT tasks_status_check CHECK (((status)::text = ANY ((ARRAY['todo'::character varying, 'in_progress'::character varying, 'blocked'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT tasks_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: training_offerings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.training_offerings (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    audience text,
    learning_objectives jsonb DEFAULT '[]'::jsonb NOT NULL,
    topics jsonb DEFAULT '[]'::jsonb NOT NULL,
    delivery_format character varying,
    seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_title character varying,
    published_summary text,
    published_body text,
    published_audience text,
    published_learning_objectives jsonb DEFAULT '[]'::jsonb NOT NULL,
    published_topics jsonb DEFAULT '[]'::jsonb NOT NULL,
    published_delivery_format character varying,
    published_seo jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_membership_id bigint,
    updated_by_membership_id bigint,
    approved_by_membership_id bigint,
    published_by_membership_id bigint,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT training_offerings_status_check CHECK (((status)::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])))
);


--
-- Name: training_offerings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.training_offerings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: training_offerings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.training_offerings_id_seq OWNED BY public.training_offerings.id;


--
-- Name: upload_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.upload_requests (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    operating_organization_id bigint NOT NULL,
    client_organization_id bigint NOT NULL,
    title character varying NOT NULL,
    instructions text,
    document_category character varying NOT NULL,
    due_on date,
    status character varying DEFAULT 'requested'::character varying NOT NULL,
    requested_by_membership_id bigint NOT NULL,
    satisfied_document_id bigint,
    cancelled_reason text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT upload_requests_status_check CHECK (((status)::text = ANY ((ARRAY['requested'::character varying, 'submitted'::character varying, 'under_review'::character varying, 'changes_required'::character varying, 'satisfied'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT upload_requests_title_length CHECK (((char_length((title)::text) >= 1) AND (char_length((title)::text) <= 200)))
);


--
-- Name: upload_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.upload_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upload_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.upload_requests_id_seq OWNED BY public.upload_requests.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    security_version integer DEFAULT 0 NOT NULL,
    email_verified_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    full_name character varying,
    CONSTRAINT users_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying])::text[])))
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
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


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
-- Name: articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles ALTER COLUMN id SET DEFAULT nextval('public.articles_id_seq'::regclass);


--
-- Name: assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments ALTER COLUMN id SET DEFAULT nextval('public.assignments_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: case_studies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies ALTER COLUMN id SET DEFAULT nextval('public.case_studies_id_seq'::regclass);


--
-- Name: client_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contacts ALTER COLUMN id SET DEFAULT nextval('public.client_contacts_id_seq'::regclass);


--
-- Name: document_access_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants ALTER COLUMN id SET DEFAULT nextval('public.document_access_grants_id_seq'::regclass);


--
-- Name: document_releases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases ALTER COLUMN id SET DEFAULT nextval('public.document_releases_id_seq'::regclass);


--
-- Name: document_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_reviews ALTER COLUMN id SET DEFAULT nextval('public.document_reviews_id_seq'::regclass);


--
-- Name: document_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions ALTER COLUMN id SET DEFAULT nextval('public.document_versions_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: inspection_checklist_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_checklist_responses ALTER COLUMN id SET DEFAULT nextval('public.inspection_checklist_responses_id_seq'::regclass);


--
-- Name: inspection_evidence_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links ALTER COLUMN id SET DEFAULT nextval('public.inspection_evidence_links_id_seq'::regclass);


--
-- Name: inspection_findings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_findings ALTER COLUMN id SET DEFAULT nextval('public.inspection_findings_id_seq'::regclass);


--
-- Name: inspection_template_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_template_versions ALTER COLUMN id SET DEFAULT nextval('public.inspection_template_versions_id_seq'::regclass);


--
-- Name: inspection_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_templates ALTER COLUMN id SET DEFAULT nextval('public.inspection_templates_id_seq'::regclass);


--
-- Name: inspections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections ALTER COLUMN id SET DEFAULT nextval('public.inspections_id_seq'::regclass);


--
-- Name: invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations ALTER COLUMN id SET DEFAULT nextval('public.invitations_id_seq'::regclass);


--
-- Name: invoice_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items ALTER COLUMN id SET DEFAULT nextval('public.invoice_line_items_id_seq'::regclass);


--
-- Name: invoice_releases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases ALTER COLUMN id SET DEFAULT nextval('public.invoice_releases_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices ALTER COLUMN id SET DEFAULT nextval('public.invoices_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: payment_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records ALTER COLUMN id SET DEFAULT nextval('public.payment_records_id_seq'::regclass);


--
-- Name: payment_reversals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_reversals ALTER COLUMN id SET DEFAULT nextval('public.payment_reversals_id_seq'::regclass);


--
-- Name: permission_overrides id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_overrides ALTER COLUMN id SET DEFAULT nextval('public.permission_overrides_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: project_milestones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_milestones ALTER COLUMN id SET DEFAULT nextval('public.project_milestones_id_seq'::regclass);


--
-- Name: project_status_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_status_events ALTER COLUMN id SET DEFAULT nextval('public.project_status_events_id_seq'::regclass);


--
-- Name: project_updates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_updates ALTER COLUMN id SET DEFAULT nextval('public.project_updates_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: public_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources ALTER COLUMN id SET DEFAULT nextval('public.public_resources_id_seq'::regclass);


--
-- Name: public_site_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages ALTER COLUMN id SET DEFAULT nextval('public.public_site_pages_id_seq'::regclass);


--
-- Name: quote_deliveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries ALTER COLUMN id SET DEFAULT nextval('public.quote_deliveries_id_seq'::regclass);


--
-- Name: quote_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_line_items ALTER COLUMN id SET DEFAULT nextval('public.quote_line_items_id_seq'::regclass);


--
-- Name: quote_portal_releases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases ALTER COLUMN id SET DEFAULT nextval('public.quote_portal_releases_id_seq'::regclass);


--
-- Name: quote_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses ALTER COLUMN id SET DEFAULT nextval('public.quote_responses_id_seq'::regclass);


--
-- Name: quote_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions ALTER COLUMN id SET DEFAULT nextval('public.quote_revisions_id_seq'::regclass);


--
-- Name: quotes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes ALTER COLUMN id SET DEFAULT nextval('public.quotes_id_seq'::regclass);


--
-- Name: report_releases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases ALTER COLUMN id SET DEFAULT nextval('public.report_releases_id_seq'::regclass);


--
-- Name: report_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_reviews ALTER COLUMN id SET DEFAULT nextval('public.report_reviews_id_seq'::regclass);


--
-- Name: report_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions ALTER COLUMN id SET DEFAULT nextval('public.report_versions_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: role_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions ALTER COLUMN id SET DEFAULT nextval('public.role_permissions_id_seq'::regclass);


--
-- Name: schedule_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events ALTER COLUMN id SET DEFAULT nextval('public.schedule_events_id_seq'::regclass);


--
-- Name: service_inquiries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries ALTER COLUMN id SET DEFAULT nextval('public.service_inquiries_id_seq'::regclass);


--
-- Name: service_inquiry_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments ALTER COLUMN id SET DEFAULT nextval('public.service_inquiry_assignments_id_seq'::regclass);


--
-- Name: service_inquiry_clarifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications ALTER COLUMN id SET DEFAULT nextval('public.service_inquiry_clarifications_id_seq'::regclass);


--
-- Name: service_inquiry_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_notes ALTER COLUMN id SET DEFAULT nextval('public.service_inquiry_notes_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: staff_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notifications ALTER COLUMN id SET DEFAULT nextval('public.staff_notifications_id_seq'::regclass);


--
-- Name: storage_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_assets ALTER COLUMN id SET DEFAULT nextval('public.storage_assets_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: training_offerings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings ALTER COLUMN id SET DEFAULT nextval('public.training_offerings_id_seq'::regclass);


--
-- Name: upload_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests ALTER COLUMN id SET DEFAULT nextval('public.upload_requests_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


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
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: assignments assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: case_studies case_studies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT case_studies_pkey PRIMARY KEY (id);


--
-- Name: client_contacts client_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contacts
    ADD CONSTRAINT client_contacts_pkey PRIMARY KEY (id);


--
-- Name: document_access_grants document_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants
    ADD CONSTRAINT document_access_grants_pkey PRIMARY KEY (id);


--
-- Name: document_releases document_releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases
    ADD CONSTRAINT document_releases_pkey PRIMARY KEY (id);


--
-- Name: document_reviews document_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_reviews
    ADD CONSTRAINT document_reviews_pkey PRIMARY KEY (id);


--
-- Name: document_versions document_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT document_versions_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: inspection_checklist_responses inspection_checklist_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_checklist_responses
    ADD CONSTRAINT inspection_checklist_responses_pkey PRIMARY KEY (id);


--
-- Name: inspection_evidence_links inspection_evidence_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links
    ADD CONSTRAINT inspection_evidence_links_pkey PRIMARY KEY (id);


--
-- Name: inspection_findings inspection_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_findings
    ADD CONSTRAINT inspection_findings_pkey PRIMARY KEY (id);


--
-- Name: inspection_template_versions inspection_template_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_template_versions
    ADD CONSTRAINT inspection_template_versions_pkey PRIMARY KEY (id);


--
-- Name: inspection_templates inspection_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_templates
    ADD CONSTRAINT inspection_templates_pkey PRIMARY KEY (id);


--
-- Name: inspections inspections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT inspections_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: invoice_line_items invoice_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT invoice_line_items_pkey PRIMARY KEY (id);


--
-- Name: invoice_releases invoice_releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT invoice_releases_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: payment_records payment_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT payment_records_pkey PRIMARY KEY (id);


--
-- Name: payment_reversals payment_reversals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_reversals
    ADD CONSTRAINT payment_reversals_pkey PRIMARY KEY (id);


--
-- Name: permission_overrides permission_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_overrides
    ADD CONSTRAINT permission_overrides_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: project_milestones project_milestones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_milestones
    ADD CONSTRAINT project_milestones_pkey PRIMARY KEY (id);


--
-- Name: project_status_events project_status_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_status_events
    ADD CONSTRAINT project_status_events_pkey PRIMARY KEY (id);


--
-- Name: project_updates project_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_updates
    ADD CONSTRAINT project_updates_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: public_resources public_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT public_resources_pkey PRIMARY KEY (id);


--
-- Name: public_site_pages public_site_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT public_site_pages_pkey PRIMARY KEY (id);


--
-- Name: quote_deliveries quote_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT quote_deliveries_pkey PRIMARY KEY (id);


--
-- Name: quote_line_items quote_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_line_items
    ADD CONSTRAINT quote_line_items_pkey PRIMARY KEY (id);


--
-- Name: quote_portal_releases quote_portal_releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT quote_portal_releases_pkey PRIMARY KEY (id);


--
-- Name: quote_responses quote_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT quote_responses_pkey PRIMARY KEY (id);


--
-- Name: quote_revisions quote_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT quote_revisions_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);


--
-- Name: report_releases report_releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases
    ADD CONSTRAINT report_releases_pkey PRIMARY KEY (id);


--
-- Name: report_reviews report_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_reviews
    ADD CONSTRAINT report_reviews_pkey PRIMARY KEY (id);


--
-- Name: report_versions report_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions
    ADD CONSTRAINT report_versions_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: schedule_events schedule_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events
    ADD CONSTRAINT schedule_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: service_inquiries service_inquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT service_inquiries_pkey PRIMARY KEY (id);


--
-- Name: service_inquiry_assignments service_inquiry_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments
    ADD CONSTRAINT service_inquiry_assignments_pkey PRIMARY KEY (id);


--
-- Name: service_inquiry_clarifications service_inquiry_clarifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT service_inquiry_clarifications_pkey PRIMARY KEY (id);


--
-- Name: service_inquiry_notes service_inquiry_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_notes
    ADD CONSTRAINT service_inquiry_notes_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: staff_notifications staff_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notifications
    ADD CONSTRAINT staff_notifications_pkey PRIMARY KEY (id);


--
-- Name: storage_assets storage_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_assets
    ADD CONSTRAINT storage_assets_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: training_offerings training_offerings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT training_offerings_pkey PRIMARY KEY (id);


--
-- Name: upload_requests upload_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT upload_requests_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_on_contacted_by_membership_id_60558e5d9f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_contacted_by_membership_id_60558e5d9f ON public.service_inquiry_clarifications USING btree (contacted_by_membership_id);


--
-- Name: idx_on_created_by_membership_id_5421d8492b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_created_by_membership_id_5421d8492b ON public.service_inquiry_clarifications USING btree (created_by_membership_id);


--
-- Name: idx_on_inspection_id_reference_number_7f7a45af83; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_inspection_id_reference_number_7f7a45af83 ON public.inspection_findings USING btree (inspection_id, reference_number);


--
-- Name: idx_on_operating_organization_id_internal_status_3e729fa405; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_operating_organization_id_internal_status_3e729fa405 ON public.projects USING btree (operating_organization_id, internal_status);


--
-- Name: idx_on_operating_organization_id_key_85c2188d63; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_operating_organization_id_key_85c2188d63 ON public.inspection_templates USING btree (operating_organization_id, key);


--
-- Name: idx_on_operating_organization_id_status_b9750d6e1c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_operating_organization_id_status_b9750d6e1c ON public.inspection_templates USING btree (operating_organization_id, status);


--
-- Name: idx_on_report_version_id_reviewer_membership_id_852becd9b4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_report_version_id_reviewer_membership_id_852becd9b4 ON public.report_reviews USING btree (report_version_id, reviewer_membership_id);


--
-- Name: idx_on_response_recorded_by_membership_id_e5ec9fb48e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_response_recorded_by_membership_id_e5ec9fb48e ON public.service_inquiry_clarifications USING btree (response_recorded_by_membership_id);


--
-- Name: idx_on_responsible_membership_id_starts_at_76bde5637d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_responsible_membership_id_starts_at_76bde5637d ON public.schedule_events USING btree (responsible_membership_id, starts_at);


--
-- Name: idx_on_updated_by_membership_id_672df2cd34; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_updated_by_membership_id_672df2cd34 ON public.inspection_checklist_responses USING btree (updated_by_membership_id);


--
-- Name: idx_on_withdrawn_by_membership_id_03eb4e1b68; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_withdrawn_by_membership_id_03eb4e1b68 ON public.service_inquiry_clarifications USING btree (withdrawn_by_membership_id);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


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
-- Name: index_articles_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_approved_by_membership_id ON public.articles USING btree (approved_by_membership_id);


--
-- Name: index_articles_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_created_by_membership_id ON public.articles USING btree (created_by_membership_id);


--
-- Name: index_articles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_organization_id ON public.articles USING btree (organization_id);


--
-- Name: index_articles_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_organization_id_and_slug ON public.articles USING btree (organization_id, slug);


--
-- Name: index_articles_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_published_by_membership_id ON public.articles USING btree (published_by_membership_id);


--
-- Name: index_articles_on_status_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_status_and_published_at ON public.articles USING btree (status, published_at);


--
-- Name: index_articles_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_updated_by_membership_id ON public.articles USING btree (updated_by_membership_id);


--
-- Name: index_assignments_on_assigned_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_assigned_by_membership_id ON public.assignments USING btree (assigned_by_membership_id);


--
-- Name: index_assignments_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_membership_id ON public.assignments USING btree (membership_id);


--
-- Name: index_assignments_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_project_id ON public.assignments USING btree (project_id);


--
-- Name: index_assignments_on_project_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_project_id_and_active ON public.assignments USING btree (project_id, active);


--
-- Name: index_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_user_id ON public.assignments USING btree (user_id);


--
-- Name: index_assignments_on_user_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_user_id_and_active ON public.assignments USING btree (user_id, active);


--
-- Name: index_assignments_unique_active_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_assignments_unique_active_kind ON public.assignments USING btree (project_id, user_id, assignment_kind) WHERE (active = true);


--
-- Name: index_audit_events_on_actor_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_actor_membership_id ON public.audit_events USING btree (actor_membership_id);


--
-- Name: index_audit_events_on_event_type_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_event_type_and_occurred_at ON public.audit_events USING btree (event_type, occurred_at);


--
-- Name: index_audit_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id ON public.audit_events USING btree (organization_id);


--
-- Name: index_audit_events_on_organization_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id_and_occurred_at ON public.audit_events USING btree (organization_id, occurred_at);


--
-- Name: index_audit_events_on_subject_type_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_subject_type_and_subject_id ON public.audit_events USING btree (subject_type, subject_id);


--
-- Name: index_case_studies_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_approved_by_membership_id ON public.case_studies USING btree (approved_by_membership_id);


--
-- Name: index_case_studies_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_created_by_membership_id ON public.case_studies USING btree (created_by_membership_id);


--
-- Name: index_case_studies_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_organization_id ON public.case_studies USING btree (organization_id);


--
-- Name: index_case_studies_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_case_studies_on_organization_id_and_slug ON public.case_studies USING btree (organization_id, slug);


--
-- Name: index_case_studies_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_published_by_membership_id ON public.case_studies USING btree (published_by_membership_id);


--
-- Name: index_case_studies_on_status_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_status_and_published_at ON public.case_studies USING btree (status, published_at);


--
-- Name: index_case_studies_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_studies_on_updated_by_membership_id ON public.case_studies USING btree (updated_by_membership_id);


--
-- Name: index_client_contacts_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_contacts_on_created_by_membership_id ON public.client_contacts USING btree (created_by_membership_id);


--
-- Name: index_client_contacts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_contacts_on_organization_id ON public.client_contacts USING btree (organization_id);


--
-- Name: index_client_contacts_unique_active_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_contacts_unique_active_email ON public.client_contacts USING btree (organization_id, email) WHERE ((email IS NOT NULL) AND ((status)::text = 'active'::text));


--
-- Name: index_document_access_grants_on_document_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_access_grants_on_document_id_and_user_id ON public.document_access_grants USING btree (document_id, user_id) WHERE (revoked_at IS NULL);


--
-- Name: index_document_access_grants_on_granted_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_access_grants_on_granted_by_membership_id ON public.document_access_grants USING btree (granted_by_membership_id);


--
-- Name: index_document_access_grants_on_project_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_access_grants_on_project_id_and_user_id ON public.document_access_grants USING btree (project_id, user_id) WHERE (revoked_at IS NULL);


--
-- Name: index_document_access_grants_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_access_grants_on_user_id ON public.document_access_grants USING btree (user_id);


--
-- Name: index_document_releases_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_releases_on_client_organization_id ON public.document_releases USING btree (client_organization_id);


--
-- Name: index_document_releases_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_releases_on_document_id ON public.document_releases USING btree (document_id);


--
-- Name: index_document_releases_on_document_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_releases_on_document_version_id ON public.document_releases USING btree (document_version_id);


--
-- Name: index_document_releases_on_released_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_releases_on_released_by_membership_id ON public.document_releases USING btree (released_by_membership_id);


--
-- Name: index_document_releases_one_active_per_document; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_releases_one_active_per_document ON public.document_releases USING btree (document_id) WHERE (revoked_at IS NULL);


--
-- Name: index_document_releases_one_active_per_document_client; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_releases_one_active_per_document_client ON public.document_releases USING btree (document_id, client_organization_id) WHERE (revoked_at IS NULL);


--
-- Name: index_document_reviews_on_document_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_reviews_on_document_version_id ON public.document_reviews USING btree (document_version_id);


--
-- Name: index_document_reviews_on_reviewer_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_reviews_on_reviewer_membership_id ON public.document_reviews USING btree (reviewer_membership_id);


--
-- Name: index_document_reviews_open_per_version_reviewer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_reviews_open_per_version_reviewer ON public.document_reviews USING btree (document_version_id, reviewer_membership_id) WHERE (decided_at IS NULL);


--
-- Name: index_document_versions_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_versions_on_document_id ON public.document_versions USING btree (document_id);


--
-- Name: index_document_versions_on_document_id_and_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_on_document_id_and_version_number ON public.document_versions USING btree (document_id, version_number);


--
-- Name: index_document_versions_on_storage_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_on_storage_asset_id ON public.document_versions USING btree (storage_asset_id);


--
-- Name: index_document_versions_on_uploaded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_versions_on_uploaded_by_membership_id ON public.document_versions USING btree (uploaded_by_membership_id);


--
-- Name: index_documents_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_client_organization_id ON public.documents USING btree (client_organization_id);


--
-- Name: index_documents_on_client_organization_id_and_workflow_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_client_organization_id_and_workflow_status ON public.documents USING btree (client_organization_id, workflow_status);


--
-- Name: index_documents_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_created_by_membership_id ON public.documents USING btree (created_by_membership_id);


--
-- Name: index_documents_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_operating_organization_id ON public.documents USING btree (operating_organization_id);


--
-- Name: index_documents_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_project_id ON public.documents USING btree (project_id);


--
-- Name: index_documents_on_project_id_and_workflow_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_project_id_and_workflow_status ON public.documents USING btree (project_id, workflow_status);


--
-- Name: index_documents_on_upload_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_upload_request_id ON public.documents USING btree (upload_request_id);


--
-- Name: index_inspection_checklist_responses_on_inspection_and_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inspection_checklist_responses_on_inspection_and_item ON public.inspection_checklist_responses USING btree (inspection_id, item_key);


--
-- Name: index_inspection_checklist_responses_on_inspection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_checklist_responses_on_inspection_id ON public.inspection_checklist_responses USING btree (inspection_id);


--
-- Name: index_inspection_evidence_links_on_attached_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_evidence_links_on_attached_by_membership_id ON public.inspection_evidence_links USING btree (attached_by_membership_id);


--
-- Name: index_inspection_evidence_links_on_document_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_evidence_links_on_document_version_id ON public.inspection_evidence_links USING btree (document_version_id);


--
-- Name: index_inspection_evidence_links_on_finding_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_evidence_links_on_finding_id ON public.inspection_evidence_links USING btree (finding_id);


--
-- Name: index_inspection_evidence_links_on_inspection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_evidence_links_on_inspection_id ON public.inspection_evidence_links USING btree (inspection_id);


--
-- Name: index_inspection_evidence_links_unique_attachment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inspection_evidence_links_unique_attachment ON public.inspection_evidence_links USING btree (inspection_id, document_version_id, checklist_item_key);


--
-- Name: index_inspection_findings_on_inspection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_findings_on_inspection_id ON public.inspection_findings USING btree (inspection_id);


--
-- Name: index_inspection_findings_on_recorded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_findings_on_recorded_by_membership_id ON public.inspection_findings USING btree (recorded_by_membership_id);


--
-- Name: index_inspection_template_versions_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_template_versions_on_created_by_membership_id ON public.inspection_template_versions USING btree (created_by_membership_id);


--
-- Name: index_inspection_template_versions_on_inspection_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_template_versions_on_inspection_template_id ON public.inspection_template_versions USING btree (inspection_template_id);


--
-- Name: index_inspection_template_versions_on_template_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inspection_template_versions_on_template_and_number ON public.inspection_template_versions USING btree (inspection_template_id, version_number);


--
-- Name: index_inspection_templates_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_templates_on_operating_organization_id ON public.inspection_templates USING btree (operating_organization_id);


--
-- Name: index_inspection_templates_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspection_templates_on_service_id ON public.inspection_templates USING btree (service_id);


--
-- Name: index_inspections_on_assigned_surveyor_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_assigned_surveyor_membership_id ON public.inspections USING btree (assigned_surveyor_membership_id);


--
-- Name: index_inspections_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_client_organization_id ON public.inspections USING btree (client_organization_id);


--
-- Name: index_inspections_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_created_by_membership_id ON public.inspections USING btree (created_by_membership_id);


--
-- Name: index_inspections_on_inspection_template_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_inspection_template_version_id ON public.inspections USING btree (inspection_template_version_id);


--
-- Name: index_inspections_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_operating_organization_id ON public.inspections USING btree (operating_organization_id);


--
-- Name: index_inspections_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_project_id ON public.inspections USING btree (project_id);


--
-- Name: index_inspections_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_project_id_and_status ON public.inspections USING btree (project_id, status);


--
-- Name: index_inspections_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inspections_on_reference_number ON public.inspections USING btree (reference_number);


--
-- Name: index_inspections_on_schedule_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_schedule_event_id ON public.inspections USING btree (schedule_event_id);


--
-- Name: index_inspections_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inspections_on_service_id ON public.inspections USING btree (service_id);


--
-- Name: index_invitations_on_accepted_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_accepted_by_user_id ON public.invitations USING btree (accepted_by_user_id);


--
-- Name: index_invitations_on_email_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_email_and_organization_id ON public.invitations USING btree (email, organization_id);


--
-- Name: index_invitations_on_invited_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_invited_by_membership_id ON public.invitations USING btree (invited_by_membership_id);


--
-- Name: index_invitations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_organization_id ON public.invitations USING btree (organization_id);


--
-- Name: index_invitations_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_organization_id_and_status ON public.invitations USING btree (organization_id, status);


--
-- Name: index_invitations_unique_pending_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_unique_pending_token_digest ON public.invitations USING btree (token_digest) WHERE ((status)::text = 'pending'::text);


--
-- Name: index_invoice_line_items_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_line_items_on_invoice_id ON public.invoice_line_items USING btree (invoice_id);


--
-- Name: index_invoice_line_items_on_invoice_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_line_items_on_invoice_id_and_position ON public.invoice_line_items USING btree (invoice_id, "position");


--
-- Name: index_invoice_line_items_on_quote_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_line_items_on_quote_line_item_id ON public.invoice_line_items USING btree (quote_line_item_id);


--
-- Name: index_invoice_releases_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_client_organization_id ON public.invoice_releases USING btree (client_organization_id);


--
-- Name: index_invoice_releases_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_invoice_id ON public.invoice_releases USING btree (invoice_id);


--
-- Name: index_invoice_releases_on_invoice_id_and_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_invoice_id_and_revoked_at ON public.invoice_releases USING btree (invoice_id, revoked_at);


--
-- Name: index_invoice_releases_on_released_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_released_by_membership_id ON public.invoice_releases USING btree (released_by_membership_id);


--
-- Name: index_invoice_releases_on_revoked_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_revoked_by_membership_id ON public.invoice_releases USING btree (revoked_by_membership_id);


--
-- Name: index_invoice_releases_on_storage_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_releases_on_storage_asset_id ON public.invoice_releases USING btree (storage_asset_id);


--
-- Name: index_invoices_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_client_organization_id ON public.invoices USING btree (client_organization_id);


--
-- Name: index_invoices_on_client_organization_id_and_issue_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_client_organization_id_and_issue_status ON public.invoices USING btree (client_organization_id, issue_status);


--
-- Name: index_invoices_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_created_by_membership_id ON public.invoices USING btree (created_by_membership_id);


--
-- Name: index_invoices_on_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_due_on ON public.invoices USING btree (due_on);


--
-- Name: index_invoices_on_issued_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_issued_by_membership_id ON public.invoices USING btree (issued_by_membership_id);


--
-- Name: index_invoices_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_operating_organization_id ON public.invoices USING btree (operating_organization_id);


--
-- Name: index_invoices_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_project_id ON public.invoices USING btree (project_id);


--
-- Name: index_invoices_on_project_id_and_issue_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_project_id_and_issue_status ON public.invoices USING btree (project_id, issue_status);


--
-- Name: index_invoices_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_quote_id ON public.invoices USING btree (quote_id);


--
-- Name: index_invoices_on_quote_response_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_quote_response_id ON public.invoices USING btree (quote_response_id);


--
-- Name: index_invoices_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_quote_revision_id ON public.invoices USING btree (quote_revision_id);


--
-- Name: index_invoices_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_on_reference_number ON public.invoices USING btree (reference_number);


--
-- Name: index_invoices_on_storage_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_storage_asset_id ON public.invoices USING btree (storage_asset_id);


--
-- Name: index_invoices_on_voided_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_voided_by_membership_id ON public.invoices USING btree (voided_by_membership_id);


--
-- Name: index_memberships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id ON public.memberships USING btree (organization_id);


--
-- Name: index_memberships_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id_and_status ON public.memberships USING btree (organization_id, status);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_memberships_on_user_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_user_id_and_organization_id ON public.memberships USING btree (user_id, organization_id);


--
-- Name: index_memberships_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id_and_status ON public.memberships USING btree (user_id, status);


--
-- Name: index_organizations_on_kind_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_kind_and_status ON public.organizations USING btree (kind, status);


--
-- Name: index_organizations_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_reference_number ON public.organizations USING btree (reference_number) WHERE (reference_number IS NOT NULL);


--
-- Name: index_organizations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_slug ON public.organizations USING btree (slug);


--
-- Name: index_organizations_unique_active_ant_marine; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_unique_active_ant_marine ON public.organizations USING btree (kind) WHERE (((kind)::text = 'ant_marine'::text) AND (archived_at IS NULL));


--
-- Name: index_payment_records_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_records_on_invoice_id ON public.payment_records USING btree (invoice_id);


--
-- Name: index_payment_records_on_recorded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_records_on_recorded_by_membership_id ON public.payment_records USING btree (recorded_by_membership_id);


--
-- Name: index_payment_reversals_on_payment_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_reversals_on_payment_record_id ON public.payment_reversals USING btree (payment_record_id);


--
-- Name: index_payment_reversals_on_recorded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_reversals_on_recorded_by_membership_id ON public.payment_reversals USING btree (recorded_by_membership_id);


--
-- Name: index_permission_overrides_on_granted_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permission_overrides_on_granted_by_membership_id ON public.permission_overrides USING btree (granted_by_membership_id);


--
-- Name: index_permission_overrides_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permission_overrides_on_membership_id ON public.permission_overrides USING btree (membership_id);


--
-- Name: index_permission_overrides_on_membership_id_and_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permission_overrides_on_membership_id_and_permission_id ON public.permission_overrides USING btree (membership_id, permission_id);


--
-- Name: index_permission_overrides_on_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permission_overrides_on_permission_id ON public.permission_overrides USING btree (permission_id);


--
-- Name: index_permissions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_key ON public.permissions USING btree (key);


--
-- Name: index_project_milestones_on_completed_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_milestones_on_completed_by_membership_id ON public.project_milestones USING btree (completed_by_membership_id);


--
-- Name: index_project_milestones_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_milestones_on_project_id ON public.project_milestones USING btree (project_id);


--
-- Name: index_project_milestones_on_project_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_milestones_on_project_id_and_position ON public.project_milestones USING btree (project_id, "position");


--
-- Name: index_project_milestones_on_responsible_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_milestones_on_responsible_membership_id ON public.project_milestones USING btree (responsible_membership_id);


--
-- Name: index_project_status_events_on_actor_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_status_events_on_actor_membership_id ON public.project_status_events USING btree (actor_membership_id);


--
-- Name: index_project_status_events_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_status_events_on_project_id ON public.project_status_events USING btree (project_id);


--
-- Name: index_project_status_events_on_project_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_status_events_on_project_id_and_occurred_at ON public.project_status_events USING btree (project_id, occurred_at);


--
-- Name: index_project_updates_on_author_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_updates_on_author_membership_id ON public.project_updates USING btree (author_membership_id);


--
-- Name: index_project_updates_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_updates_on_project_id ON public.project_updates USING btree (project_id);


--
-- Name: index_project_updates_on_project_id_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_updates_on_project_id_and_published_at ON public.project_updates USING btree (project_id, published_at);


--
-- Name: index_projects_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_client_organization_id ON public.projects USING btree (client_organization_id);


--
-- Name: index_projects_on_client_organization_id_and_client_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_client_organization_id_and_client_status ON public.projects USING btree (client_organization_id, client_status);


--
-- Name: index_projects_on_coordinator_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_coordinator_membership_id ON public.projects USING btree (coordinator_membership_id);


--
-- Name: index_projects_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_created_by_membership_id ON public.projects USING btree (created_by_membership_id);


--
-- Name: index_projects_on_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_mode ON public.projects USING btree (mode);


--
-- Name: index_projects_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_operating_organization_id ON public.projects USING btree (operating_organization_id);


--
-- Name: index_projects_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_quote_id ON public.projects USING btree (quote_id);


--
-- Name: index_projects_on_quote_portal_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_quote_portal_release_id ON public.projects USING btree (quote_portal_release_id);


--
-- Name: index_projects_on_quote_response_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_quote_response_id ON public.projects USING btree (quote_response_id);


--
-- Name: index_projects_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_quote_revision_id ON public.projects USING btree (quote_revision_id);


--
-- Name: index_projects_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_reference_number ON public.projects USING btree (reference_number);


--
-- Name: index_projects_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_service_id ON public.projects USING btree (service_id);


--
-- Name: index_projects_on_service_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_service_inquiry_id ON public.projects USING btree (service_inquiry_id);


--
-- Name: index_public_resources_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_approved_by_membership_id ON public.public_resources USING btree (approved_by_membership_id);


--
-- Name: index_public_resources_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_created_by_membership_id ON public.public_resources USING btree (created_by_membership_id);


--
-- Name: index_public_resources_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_organization_id ON public.public_resources USING btree (organization_id);


--
-- Name: index_public_resources_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_public_resources_on_organization_id_and_slug ON public.public_resources USING btree (organization_id, slug);


--
-- Name: index_public_resources_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_published_by_membership_id ON public.public_resources USING btree (published_by_membership_id);


--
-- Name: index_public_resources_on_status_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_status_and_published_at ON public.public_resources USING btree (status, published_at);


--
-- Name: index_public_resources_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_resources_on_updated_by_membership_id ON public.public_resources USING btree (updated_by_membership_id);


--
-- Name: index_public_site_pages_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_approved_by_membership_id ON public.public_site_pages USING btree (approved_by_membership_id);


--
-- Name: index_public_site_pages_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_created_by_membership_id ON public.public_site_pages USING btree (created_by_membership_id);


--
-- Name: index_public_site_pages_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_organization_id ON public.public_site_pages USING btree (organization_id);


--
-- Name: index_public_site_pages_on_organization_id_and_page_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_public_site_pages_on_organization_id_and_page_key ON public.public_site_pages USING btree (organization_id, page_key);


--
-- Name: index_public_site_pages_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_published_by_membership_id ON public.public_site_pages USING btree (published_by_membership_id);


--
-- Name: index_public_site_pages_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_status ON public.public_site_pages USING btree (status);


--
-- Name: index_public_site_pages_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_site_pages_on_updated_by_membership_id ON public.public_site_pages USING btree (updated_by_membership_id);


--
-- Name: index_quote_deliveries_on_dispatched_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_deliveries_on_dispatched_by_membership_id ON public.quote_deliveries USING btree (dispatched_by_membership_id);


--
-- Name: index_quote_deliveries_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_deliveries_on_idempotency_key ON public.quote_deliveries USING btree (idempotency_key);


--
-- Name: index_quote_deliveries_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_deliveries_on_organization_id ON public.quote_deliveries USING btree (organization_id);


--
-- Name: index_quote_deliveries_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_deliveries_on_quote_id ON public.quote_deliveries USING btree (quote_id);


--
-- Name: index_quote_deliveries_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_deliveries_on_quote_revision_id ON public.quote_deliveries USING btree (quote_revision_id);


--
-- Name: index_quote_deliveries_on_requested_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_deliveries_on_requested_by_membership_id ON public.quote_deliveries USING btree (requested_by_membership_id);


--
-- Name: index_quote_deliveries_one_live_per_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_deliveries_one_live_per_revision ON public.quote_deliveries USING btree (quote_revision_id) WHERE ((status)::text = ANY ((ARRAY['prepared'::character varying, 'queued'::character varying, 'sending'::character varying, 'accepted_by_provider'::character varying, 'outcome_unknown'::character varying, 'delivery_confirmed'::character varying])::text[]));


--
-- Name: index_quote_line_items_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_line_items_on_quote_revision_id ON public.quote_line_items USING btree (quote_revision_id);


--
-- Name: index_quote_line_items_on_quote_revision_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_line_items_on_quote_revision_id_and_position ON public.quote_line_items USING btree (quote_revision_id, "position");


--
-- Name: index_quote_portal_releases_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_client_organization_id ON public.quote_portal_releases USING btree (client_organization_id);


--
-- Name: index_quote_portal_releases_on_org_and_released_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_org_and_released_at ON public.quote_portal_releases USING btree (client_organization_id, released_at);


--
-- Name: index_quote_portal_releases_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_quote_id ON public.quote_portal_releases USING btree (quote_id);


--
-- Name: index_quote_portal_releases_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_quote_revision_id ON public.quote_portal_releases USING btree (quote_revision_id);


--
-- Name: index_quote_portal_releases_on_released_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_released_by_membership_id ON public.quote_portal_releases USING btree (released_by_membership_id);


--
-- Name: index_quote_portal_releases_on_revoked_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_portal_releases_on_revoked_by_membership_id ON public.quote_portal_releases USING btree (revoked_by_membership_id);


--
-- Name: index_quote_portal_releases_unique_revision_org; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_portal_releases_unique_revision_org ON public.quote_portal_releases USING btree (quote_revision_id, client_organization_id);


--
-- Name: index_quote_responses_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_client_organization_id ON public.quote_responses USING btree (client_organization_id);


--
-- Name: index_quote_responses_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_responses_on_idempotency_key ON public.quote_responses USING btree (idempotency_key);


--
-- Name: index_quote_responses_on_org_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_org_and_created_at ON public.quote_responses USING btree (client_organization_id, created_at);


--
-- Name: index_quote_responses_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_quote_id ON public.quote_responses USING btree (quote_id);


--
-- Name: index_quote_responses_on_quote_portal_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_quote_portal_release_id ON public.quote_responses USING btree (quote_portal_release_id);


--
-- Name: index_quote_responses_on_quote_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_quote_revision_id ON public.quote_responses USING btree (quote_revision_id);


--
-- Name: index_quote_responses_on_responded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_responses_on_responded_by_membership_id ON public.quote_responses USING btree (responded_by_membership_id);


--
-- Name: index_quote_responses_one_terminal_per_release; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_responses_one_terminal_per_release ON public.quote_responses USING btree (quote_portal_release_id, response) WHERE ((response)::text = ANY ((ARRAY['accepted'::character varying, 'declined'::character varying])::text[]));


--
-- Name: index_quote_revisions_on_predecessor_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_revisions_on_predecessor_revision_id ON public.quote_revisions USING btree (predecessor_revision_id);


--
-- Name: index_quote_revisions_on_prepared_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_revisions_on_prepared_by_membership_id ON public.quote_revisions USING btree (prepared_by_membership_id);


--
-- Name: index_quote_revisions_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_revisions_on_quote_id ON public.quote_revisions USING btree (quote_id);


--
-- Name: index_quote_revisions_on_quote_id_and_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quote_revisions_on_quote_id_and_version_number ON public.quote_revisions USING btree (quote_id, version_number);


--
-- Name: index_quote_revisions_on_submitted_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_revisions_on_submitted_by_membership_id ON public.quote_revisions USING btree (submitted_by_membership_id);


--
-- Name: index_quote_revisions_on_superseded_by_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_revisions_on_superseded_by_revision_id ON public.quote_revisions USING btree (superseded_by_revision_id);


--
-- Name: index_quotes_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_client_organization_id ON public.quotes USING btree (client_organization_id);


--
-- Name: index_quotes_on_current_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_current_revision_id ON public.quotes USING btree (current_revision_id);


--
-- Name: index_quotes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_organization_id ON public.quotes USING btree (organization_id);


--
-- Name: index_quotes_on_organization_id_and_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quotes_on_organization_id_and_reference_number ON public.quotes USING btree (organization_id, reference_number);


--
-- Name: index_quotes_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_service_id ON public.quotes USING btree (service_id);


--
-- Name: index_quotes_on_service_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_service_inquiry_id ON public.quotes USING btree (service_inquiry_id);


--
-- Name: index_quotes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_status ON public.quotes USING btree (status);


--
-- Name: index_quotes_one_open_quote_per_inquiry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quotes_one_open_quote_per_inquiry ON public.quotes USING btree (service_inquiry_id) WHERE ((service_inquiry_id IS NOT NULL) AND ((status)::text <> ALL ((ARRAY['withdrawn'::character varying, 'superseded'::character varying])::text[])));


--
-- Name: index_report_releases_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_releases_on_client_organization_id ON public.report_releases USING btree (client_organization_id);


--
-- Name: index_report_releases_on_released_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_releases_on_released_by_membership_id ON public.report_releases USING btree (released_by_membership_id);


--
-- Name: index_report_releases_on_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_releases_on_report_id ON public.report_releases USING btree (report_id);


--
-- Name: index_report_releases_on_report_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_releases_on_report_version_id ON public.report_releases USING btree (report_version_id);


--
-- Name: index_report_releases_one_active_per_report; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_report_releases_one_active_per_report ON public.report_releases USING btree (report_id) WHERE (revoked_at IS NULL);


--
-- Name: index_report_releases_one_active_per_report_client; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_report_releases_one_active_per_report_client ON public.report_releases USING btree (report_id, client_organization_id) WHERE (revoked_at IS NULL);


--
-- Name: index_report_reviews_on_report_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_reviews_on_report_version_id ON public.report_reviews USING btree (report_version_id);


--
-- Name: index_report_reviews_on_reviewer_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_reviews_on_reviewer_membership_id ON public.report_reviews USING btree (reviewer_membership_id);


--
-- Name: index_report_versions_on_authored_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_versions_on_authored_by_membership_id ON public.report_versions USING btree (authored_by_membership_id);


--
-- Name: index_report_versions_on_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_versions_on_report_id ON public.report_versions USING btree (report_id);


--
-- Name: index_report_versions_on_report_id_and_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_report_versions_on_report_id_and_version_number ON public.report_versions USING btree (report_id, version_number);


--
-- Name: index_report_versions_on_storage_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_versions_on_storage_asset_id ON public.report_versions USING btree (storage_asset_id);


--
-- Name: index_report_versions_on_submitted_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_versions_on_submitted_by_membership_id ON public.report_versions USING btree (submitted_by_membership_id);


--
-- Name: index_reports_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_client_organization_id ON public.reports USING btree (client_organization_id);


--
-- Name: index_reports_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_created_by_membership_id ON public.reports USING btree (created_by_membership_id);


--
-- Name: index_reports_on_inspection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_inspection_id ON public.reports USING btree (inspection_id);


--
-- Name: index_reports_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_operating_organization_id ON public.reports USING btree (operating_organization_id);


--
-- Name: index_reports_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_project_id ON public.reports USING btree (project_id);


--
-- Name: index_reports_on_project_id_and_report_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_project_id_and_report_kind ON public.reports USING btree (project_id, report_kind);


--
-- Name: index_reports_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reports_on_reference_number ON public.reports USING btree (reference_number);


--
-- Name: index_role_permissions_on_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_permission_id ON public.role_permissions USING btree (permission_id);


--
-- Name: index_role_permissions_on_role_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_role_key ON public.role_permissions USING btree (role_key);


--
-- Name: index_role_permissions_on_role_key_and_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_role_permissions_on_role_key_and_permission_id ON public.role_permissions USING btree (role_key, permission_id);


--
-- Name: index_schedule_events_on_confirmation_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_confirmation_state ON public.schedule_events USING btree (confirmation_state);


--
-- Name: index_schedule_events_on_confirmed_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_confirmed_by_membership_id ON public.schedule_events USING btree (confirmed_by_membership_id);


--
-- Name: index_schedule_events_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_created_by_membership_id ON public.schedule_events USING btree (created_by_membership_id);


--
-- Name: index_schedule_events_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_project_id ON public.schedule_events USING btree (project_id);


--
-- Name: index_schedule_events_on_project_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_project_id_and_starts_at ON public.schedule_events USING btree (project_id, starts_at);


--
-- Name: index_schedule_events_on_responsible_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_events_on_responsible_membership_id ON public.schedule_events USING btree (responsible_membership_id);


--
-- Name: index_service_inquiries_on_assigned_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_assigned_membership_id ON public.service_inquiries USING btree (assigned_membership_id);


--
-- Name: index_service_inquiries_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_client_organization_id ON public.service_inquiries USING btree (client_organization_id);


--
-- Name: index_service_inquiries_on_current_status_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_current_status_and_created_at ON public.service_inquiries USING btree (current_status, created_at);


--
-- Name: index_service_inquiries_on_duplicate_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_duplicate_of_id ON public.service_inquiries USING btree (duplicate_of_id);


--
-- Name: index_service_inquiries_on_org_assignee_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_org_assignee_status ON public.service_inquiries USING btree (organization_id, assigned_membership_id, current_status);


--
-- Name: index_service_inquiries_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_organization_id ON public.service_inquiries USING btree (organization_id);


--
-- Name: index_service_inquiries_on_reference_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_inquiries_on_reference_number ON public.service_inquiries USING btree (reference_number);


--
-- Name: index_service_inquiries_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiries_on_service_id ON public.service_inquiries USING btree (service_id);


--
-- Name: index_service_inquiries_on_submission_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_inquiries_on_submission_token ON public.service_inquiries USING btree (submission_token);


--
-- Name: index_service_inquiry_assignments_on_actor_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_assignments_on_actor_membership_id ON public.service_inquiry_assignments USING btree (actor_membership_id);


--
-- Name: index_service_inquiry_assignments_on_new_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_assignments_on_new_membership_id ON public.service_inquiry_assignments USING btree (new_membership_id);


--
-- Name: index_service_inquiry_assignments_on_previous_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_assignments_on_previous_membership_id ON public.service_inquiry_assignments USING btree (previous_membership_id);


--
-- Name: index_service_inquiry_assignments_on_service_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_assignments_on_service_inquiry_id ON public.service_inquiry_assignments USING btree (service_inquiry_id);


--
-- Name: index_service_inquiry_clarifications_on_service_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_clarifications_on_service_inquiry_id ON public.service_inquiry_clarifications USING btree (service_inquiry_id);


--
-- Name: index_service_inquiry_notes_on_author_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_notes_on_author_membership_id ON public.service_inquiry_notes USING btree (author_membership_id);


--
-- Name: index_service_inquiry_notes_on_corrects_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_inquiry_notes_on_corrects_note_id ON public.service_inquiry_notes USING btree (corrects_note_id);


--
-- Name: index_service_inquiry_notes_on_service_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_inquiry_notes_on_service_inquiry_id ON public.service_inquiry_notes USING btree (service_inquiry_id);


--
-- Name: index_services_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_approved_by_membership_id ON public.services USING btree (approved_by_membership_id);


--
-- Name: index_services_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_created_by_membership_id ON public.services USING btree (created_by_membership_id);


--
-- Name: index_services_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_organization_id ON public.services USING btree (organization_id);


--
-- Name: index_services_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_services_on_organization_id_and_slug ON public.services USING btree (organization_id, slug);


--
-- Name: index_services_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_published_by_membership_id ON public.services USING btree (published_by_membership_id);


--
-- Name: index_services_on_status_and_display_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_status_and_display_order ON public.services USING btree (status, display_order);


--
-- Name: index_services_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_updated_by_membership_id ON public.services USING btree (updated_by_membership_id);


--
-- Name: index_sessions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_expires_at ON public.sessions USING btree (expires_at);


--
-- Name: index_sessions_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_membership_id ON public.sessions USING btree (membership_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_sessions_on_user_id_and_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id_and_revoked_at ON public.sessions USING btree (user_id, revoked_at);


--
-- Name: index_staff_notifications_on_audit_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notifications_on_audit_event_id ON public.staff_notifications USING btree (audit_event_id);


--
-- Name: index_staff_notifications_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notifications_on_organization_id ON public.staff_notifications USING btree (organization_id);


--
-- Name: index_staff_notifications_on_recipient_and_dedupe_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_notifications_on_recipient_and_dedupe_key ON public.staff_notifications USING btree (recipient_membership_id, dedupe_key);


--
-- Name: index_staff_notifications_on_recipient_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notifications_on_recipient_unread ON public.staff_notifications USING btree (recipient_membership_id, read_at, created_at);


--
-- Name: index_storage_assets_on_active_storage_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_assets_on_active_storage_blob_id ON public.storage_assets USING btree (active_storage_blob_id);


--
-- Name: index_storage_assets_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_assets_on_organization_id ON public.storage_assets USING btree (organization_id);


--
-- Name: index_storage_assets_on_scan_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_assets_on_scan_status ON public.storage_assets USING btree (scan_status);


--
-- Name: index_storage_assets_on_storage_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_storage_assets_on_storage_key ON public.storage_assets USING btree (storage_key);


--
-- Name: index_storage_assets_on_uploaded_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_storage_assets_on_uploaded_by_membership_id ON public.storage_assets USING btree (uploaded_by_membership_id);


--
-- Name: index_tasks_on_assignee_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_assignee_membership_id ON public.tasks USING btree (assignee_membership_id);


--
-- Name: index_tasks_on_assignee_membership_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_assignee_membership_id_and_status ON public.tasks USING btree (assignee_membership_id, status);


--
-- Name: index_tasks_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_created_by_membership_id ON public.tasks USING btree (created_by_membership_id);


--
-- Name: index_tasks_on_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_due_on ON public.tasks USING btree (due_on);


--
-- Name: index_tasks_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_project_id ON public.tasks USING btree (project_id);


--
-- Name: index_tasks_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_project_id_and_status ON public.tasks USING btree (project_id, status);


--
-- Name: index_training_offerings_on_approved_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_approved_by_membership_id ON public.training_offerings USING btree (approved_by_membership_id);


--
-- Name: index_training_offerings_on_created_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_created_by_membership_id ON public.training_offerings USING btree (created_by_membership_id);


--
-- Name: index_training_offerings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_organization_id ON public.training_offerings USING btree (organization_id);


--
-- Name: index_training_offerings_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_training_offerings_on_organization_id_and_slug ON public.training_offerings USING btree (organization_id, slug);


--
-- Name: index_training_offerings_on_published_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_published_by_membership_id ON public.training_offerings USING btree (published_by_membership_id);


--
-- Name: index_training_offerings_on_status_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_status_and_published_at ON public.training_offerings USING btree (status, published_at);


--
-- Name: index_training_offerings_on_updated_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_training_offerings_on_updated_by_membership_id ON public.training_offerings USING btree (updated_by_membership_id);


--
-- Name: index_upload_requests_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_client_organization_id ON public.upload_requests USING btree (client_organization_id);


--
-- Name: index_upload_requests_on_operating_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_operating_organization_id ON public.upload_requests USING btree (operating_organization_id);


--
-- Name: index_upload_requests_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_project_id ON public.upload_requests USING btree (project_id);


--
-- Name: index_upload_requests_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_project_id_and_status ON public.upload_requests USING btree (project_id, status);


--
-- Name: index_upload_requests_on_requested_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_requested_by_membership_id ON public.upload_requests USING btree (requested_by_membership_id);


--
-- Name: index_upload_requests_on_satisfied_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_requests_on_satisfied_document_id ON public.upload_requests USING btree (satisfied_document_id);


--
-- Name: index_users_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_lower_email ON public.users USING btree (lower((email)::text));


--
-- Name: document_releases document_releases_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER document_releases_protect BEFORE DELETE OR UPDATE ON public.document_releases FOR EACH ROW EXECUTE FUNCTION public.ant_marine_document_release_protect();


--
-- Name: document_versions document_versions_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER document_versions_protect BEFORE DELETE OR UPDATE ON public.document_versions FOR EACH ROW EXECUTE FUNCTION public.ant_marine_document_version_protect();


--
-- Name: inspection_evidence_links inspection_evidence_links_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inspection_evidence_links_protect BEFORE DELETE ON public.inspection_evidence_links FOR EACH ROW EXECUTE FUNCTION public.ant_marine_inspection_evidence_link_protect();


--
-- Name: inspection_template_versions inspection_template_versions_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inspection_template_versions_protect BEFORE DELETE OR UPDATE ON public.inspection_template_versions FOR EACH ROW EXECUTE FUNCTION public.ant_marine_inspection_template_version_protect();


--
-- Name: invoice_line_items invoice_line_items_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoice_line_items_protect BEFORE INSERT OR DELETE OR UPDATE ON public.invoice_line_items FOR EACH ROW EXECUTE FUNCTION public.ant_marine_invoice_line_item_protect();


--
-- Name: invoice_releases invoice_releases_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoice_releases_protect BEFORE DELETE OR UPDATE ON public.invoice_releases FOR EACH ROW EXECUTE FUNCTION public.ant_marine_invoice_release_protect();


--
-- Name: invoices invoices_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoices_protect BEFORE DELETE OR UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.ant_marine_invoice_protect();


--
-- Name: payment_records payment_records_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_records_protect BEFORE DELETE OR UPDATE ON public.payment_records FOR EACH ROW EXECUTE FUNCTION public.ant_marine_payment_record_protect();


--
-- Name: payment_reversals payment_reversals_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_reversals_protect BEFORE DELETE OR UPDATE ON public.payment_reversals FOR EACH ROW EXECUTE FUNCTION public.ant_marine_payment_reversal_protect();


--
-- Name: projects projects_commercial_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_commercial_protect BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.ant_marine_project_commercial_protect();


--
-- Name: quote_line_items quote_line_items_history_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quote_line_items_history_protect BEFORE INSERT OR DELETE OR UPDATE ON public.quote_line_items FOR EACH ROW EXECUTE FUNCTION public.ant_marine_quote_line_item_protect();


--
-- Name: quote_responses quote_responses_history_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quote_responses_history_protect BEFORE DELETE OR UPDATE ON public.quote_responses FOR EACH ROW EXECUTE FUNCTION public.ant_marine_quote_response_protect();


--
-- Name: quote_revisions quote_revisions_history_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quote_revisions_history_protect BEFORE DELETE OR UPDATE ON public.quote_revisions FOR EACH ROW EXECUTE FUNCTION public.ant_marine_quote_revision_protect();


--
-- Name: report_releases report_releases_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER report_releases_protect BEFORE DELETE OR UPDATE ON public.report_releases FOR EACH ROW EXECUTE FUNCTION public.ant_marine_report_release_protect();


--
-- Name: report_versions report_versions_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER report_versions_protect BEFORE DELETE OR UPDATE ON public.report_versions FOR EACH ROW EXECUTE FUNCTION public.ant_marine_report_version_protect();


--
-- Name: storage_assets storage_assets_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER storage_assets_protect BEFORE UPDATE ON public.storage_assets FOR EACH ROW EXECUTE FUNCTION public.ant_marine_storage_asset_protect();


--
-- Name: quote_deliveries fk_rails_000eeecdbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT fk_rails_000eeecdbf FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: inspection_templates fk_rails_029bb2ba8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_templates
    ADD CONSTRAINT fk_rails_029bb2ba8c FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: upload_requests fk_rails_02b246319c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT fk_rails_02b246319c FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: tasks fk_rails_02e851e3b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_02e851e3b7 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: report_releases fk_rails_030cb5ddd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases
    ADD CONSTRAINT fk_rails_030cb5ddd1 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: report_reviews fk_rails_03974995be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_reviews
    ADD CONSTRAINT fk_rails_03974995be FOREIGN KEY (reviewer_membership_id) REFERENCES public.memberships(id);


--
-- Name: documents fk_rails_03fc43389b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_03fc43389b FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspection_templates fk_rails_04476e86aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_templates
    ADD CONSTRAINT fk_rails_04476e86aa FOREIGN KEY (current_version_id) REFERENCES public.inspection_template_versions(id);


--
-- Name: document_releases fk_rails_0568e06025; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases
    ADD CONSTRAINT fk_rails_0568e06025 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: inspection_template_versions fk_rails_058335d1cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_template_versions
    ADD CONSTRAINT fk_rails_058335d1cf FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspections fk_rails_059e81e415; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_059e81e415 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: invoices fk_rails_06de90072c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_06de90072c FOREIGN KEY (storage_asset_id) REFERENCES public.storage_assets(id);


--
-- Name: projects fk_rails_07fdbba781; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_07fdbba781 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: invoices fk_rails_08adbef03a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_08adbef03a FOREIGN KEY (quote_response_id) REFERENCES public.quote_responses(id);


--
-- Name: inspection_evidence_links fk_rails_08fdaa2b59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links
    ADD CONSTRAINT fk_rails_08fdaa2b59 FOREIGN KEY (attached_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quotes fk_rails_0afeb292dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_0afeb292dc FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: inspections fk_rails_0b204a9070; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_0b204a9070 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: inspections fk_rails_0bb22eb215; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_0bb22eb215 FOREIGN KEY (schedule_event_id) REFERENCES public.schedule_events(id);


--
-- Name: report_releases fk_rails_0d3bbf1cbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases
    ADD CONSTRAINT fk_rails_0d3bbf1cbd FOREIGN KEY (report_version_id) REFERENCES public.report_versions(id);


--
-- Name: payment_reversals fk_rails_0de1e19ab9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_reversals
    ADD CONSTRAINT fk_rails_0de1e19ab9 FOREIGN KEY (payment_record_id) REFERENCES public.payment_records(id);


--
-- Name: case_studies fk_rails_0f287bf63b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT fk_rails_0f287bf63b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invitations fk_rails_0fe4c14f0e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_0fe4c14f0e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: service_inquiry_assignments fk_rails_1093d24fb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments
    ADD CONSTRAINT fk_rails_1093d24fb0 FOREIGN KEY (service_inquiry_id) REFERENCES public.service_inquiries(id);


--
-- Name: payment_records fk_rails_128884fba0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT fk_rails_128884fba0 FOREIGN KEY (recorded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: service_inquiries fk_rails_12e6fbc479; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT fk_rails_12e6fbc479 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: services fk_rails_138a98acfd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_138a98acfd FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspections fk_rails_158e51a7ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_158e51a7ee FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: inspection_findings fk_rails_16f0a8243d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_findings
    ADD CONSTRAINT fk_rails_16f0a8243d FOREIGN KEY (inspection_id) REFERENCES public.inspections(id);


--
-- Name: public_resources fk_rails_1752eaedd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT fk_rails_1752eaedd2 FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_revisions fk_rails_17643a42ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT fk_rails_17643a42ca FOREIGN KEY (predecessor_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: quote_responses fk_rails_17d3c44f5c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_17d3c44f5c FOREIGN KEY (responded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_reviews fk_rails_1b114ccc04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_reviews
    ADD CONSTRAINT fk_rails_1b114ccc04 FOREIGN KEY (reviewer_membership_id) REFERENCES public.memberships(id);


--
-- Name: project_status_events fk_rails_1de9195048; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_status_events
    ADD CONSTRAINT fk_rails_1de9195048 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: schedule_events fk_rails_218bf7f1f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events
    ADD CONSTRAINT fk_rails_218bf7f1f8 FOREIGN KEY (confirmed_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: staff_notifications fk_rails_22395b4a1a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notifications
    ADD CONSTRAINT fk_rails_22395b4a1a FOREIGN KEY (recipient_membership_id) REFERENCES public.memberships(id);


--
-- Name: upload_requests fk_rails_2273250fab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT fk_rails_2273250fab FOREIGN KEY (satisfied_document_id) REFERENCES public.documents(id);


--
-- Name: quote_responses fk_rails_2275e4ea2a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_2275e4ea2a FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: public_site_pages fk_rails_23a3fba204; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT fk_rails_23a3fba204 FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: upload_requests fk_rails_24e2a65cb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT fk_rails_24e2a65cb0 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: quote_responses fk_rails_279252d533; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_279252d533 FOREIGN KEY (responded_by_user_id) REFERENCES public.users(id);


--
-- Name: project_updates fk_rails_2b247d1bc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_updates
    ADD CONSTRAINT fk_rails_2b247d1bc3 FOREIGN KEY (author_membership_id) REFERENCES public.memberships(id);


--
-- Name: services fk_rails_2e9f369e43; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_2e9f369e43 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: document_reviews fk_rails_2f139198ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_reviews
    ADD CONSTRAINT fk_rails_2f139198ac FOREIGN KEY (document_version_id) REFERENCES public.document_versions(id);


--
-- Name: quote_line_items fk_rails_2fc1417e9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_line_items
    ADD CONSTRAINT fk_rails_2fc1417e9d FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: quote_deliveries fk_rails_323052fbb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT fk_rails_323052fbb5 FOREIGN KEY (dispatched_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: staff_notifications fk_rails_36cb95a3a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notifications
    ADD CONSTRAINT fk_rails_36cb95a3a4 FOREIGN KEY (audit_event_id) REFERENCES public.audit_events(id);


--
-- Name: service_inquiry_clarifications fk_rails_37bf85c273; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT fk_rails_37bf85c273 FOREIGN KEY (contacted_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: projects fk_rails_396e16b895; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_396e16b895 FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: reports fk_rails_39a43c4285; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_39a43c4285 FOREIGN KEY (current_version_id) REFERENCES public.report_versions(id);


--
-- Name: service_inquiry_clarifications fk_rails_39e15834b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT fk_rails_39e15834b4 FOREIGN KEY (response_recorded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: tasks fk_rails_3b9f41a231; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_3b9f41a231 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: report_releases fk_rails_3ec0b7cebc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases
    ADD CONSTRAINT fk_rails_3ec0b7cebc FOREIGN KEY (released_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: documents fk_rails_4030d9d40a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_4030d9d40a FOREIGN KEY (upload_request_id) REFERENCES public.upload_requests(id);


--
-- Name: document_access_grants fk_rails_414fa122fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants
    ADD CONSTRAINT fk_rails_414fa122fc FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: projects fk_rails_42e54ee219; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_42e54ee219 FOREIGN KEY (quote_portal_release_id) REFERENCES public.quote_portal_releases(id);


--
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: invoice_line_items fk_rails_44d85992cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT fk_rails_44d85992cd FOREIGN KEY (quote_line_item_id) REFERENCES public.quote_line_items(id);


--
-- Name: quote_responses fk_rails_4501651c40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_4501651c40 FOREIGN KEY (quote_portal_release_id) REFERENCES public.quote_portal_releases(id);


--
-- Name: public_resources fk_rails_4635c8fb84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT fk_rails_4635c8fb84 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: upload_requests fk_rails_4655b43b31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT fk_rails_4655b43b31 FOREIGN KEY (requested_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: articles fk_rails_468b56ce66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_468b56ce66 FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: services fk_rails_473627b54b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_473627b54b FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: training_offerings fk_rails_488d226d47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT fk_rails_488d226d47 FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspection_templates fk_rails_4a52f0a843; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_templates
    ADD CONSTRAINT fk_rails_4a52f0a843 FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: project_status_events fk_rails_4bc03a6f1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_status_events
    ADD CONSTRAINT fk_rails_4bc03a6f1c FOREIGN KEY (actor_membership_id) REFERENCES public.memberships(id);


--
-- Name: assignments fk_rails_4d3d2c839c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_4d3d2c839c FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: payment_reversals fk_rails_4e3ed229d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_reversals
    ADD CONSTRAINT fk_rails_4e3ed229d4 FOREIGN KEY (recorded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: project_updates fk_rails_4f9b2ad919; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_updates
    ADD CONSTRAINT fk_rails_4f9b2ad919 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: invoices fk_rails_50dd6c4fff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_50dd6c4fff FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: service_inquiries fk_rails_50e31e4c00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT fk_rails_50e31e4c00 FOREIGN KEY (duplicate_of_id) REFERENCES public.service_inquiries(id);


--
-- Name: inspection_findings fk_rails_5236e77cd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_findings
    ADD CONSTRAINT fk_rails_5236e77cd2 FOREIGN KEY (recorded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: sessions fk_rails_531ddef82b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_531ddef82b FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: schedule_events fk_rails_544b90cfb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events
    ADD CONSTRAINT fk_rails_544b90cfb5 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: documents fk_rails_55cfc1b0e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_55cfc1b0e0 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: training_offerings fk_rails_5642067273; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT fk_rails_5642067273 FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_revisions fk_rails_585287f59b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT fk_rails_585287f59b FOREIGN KEY (superseded_by_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: report_versions fk_rails_59edb745c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions
    ADD CONSTRAINT fk_rails_59edb745c9 FOREIGN KEY (report_id) REFERENCES public.reports(id);


--
-- Name: project_milestones fk_rails_5ac5d10ce0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_milestones
    ADD CONSTRAINT fk_rails_5ac5d10ce0 FOREIGN KEY (completed_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_releases fk_rails_5b6f6bc6f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases
    ADD CONSTRAINT fk_rails_5b6f6bc6f7 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: inspection_template_versions fk_rails_5bd9bee925; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_template_versions
    ADD CONSTRAINT fk_rails_5bd9bee925 FOREIGN KEY (inspection_template_id) REFERENCES public.inspection_templates(id);


--
-- Name: storage_assets fk_rails_5bf79e38ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_assets
    ADD CONSTRAINT fk_rails_5bf79e38ce FOREIGN KEY (active_storage_blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: articles fk_rails_5ccd606a6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_5ccd606a6c FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: reports fk_rails_5e53559372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_5e53559372 FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: articles fk_rails_5ecb1de37b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_5ecb1de37b FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_releases fk_rails_60f1050b0f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases
    ADD CONSTRAINT fk_rails_60f1050b0f FOREIGN KEY (released_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: reports fk_rails_6107003ca8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_6107003ca8 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: quote_portal_releases fk_rails_622397318a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT fk_rails_622397318a FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: invoices fk_rails_62d032a81e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_62d032a81e FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: reports fk_rails_62d58a0388; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_62d58a0388 FOREIGN KEY (inspection_id) REFERENCES public.inspections(id);


--
-- Name: service_inquiries fk_rails_633439a231; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT fk_rails_633439a231 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: permission_overrides fk_rails_6364aa7a07; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_overrides
    ADD CONSTRAINT fk_rails_6364aa7a07 FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: memberships fk_rails_64267aab58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_64267aab58 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quote_portal_releases fk_rails_659a07c09b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT fk_rails_659a07c09b FOREIGN KEY (released_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: service_inquiries fk_rails_671ad99b57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT fk_rails_671ad99b57 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: service_inquiry_notes fk_rails_6772e48814; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_notes
    ADD CONSTRAINT fk_rails_6772e48814 FOREIGN KEY (service_inquiry_id) REFERENCES public.service_inquiries(id);


--
-- Name: inspections fk_rails_68b0ae5376; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_68b0ae5376 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: invoices fk_rails_69fb18948b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_69fb18948b FOREIGN KEY (issued_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: service_inquiry_clarifications fk_rails_6b2318db12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT fk_rails_6b2318db12 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: invoices fk_rails_6c1bd012e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_6c1bd012e9 FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: projects fk_rails_6c1f6266c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_6c1f6266c2 FOREIGN KEY (quote_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: quote_deliveries fk_rails_6d5f4f2407; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT fk_rails_6d5f4f2407 FOREIGN KEY (requested_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: documents fk_rails_703386e8df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_703386e8df FOREIGN KEY (current_version_id) REFERENCES public.document_versions(id);


--
-- Name: invoices fk_rails_743ae81f00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_743ae81f00 FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: inspection_checklist_responses fk_rails_7448d4e834; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_checklist_responses
    ADD CONSTRAINT fk_rails_7448d4e834 FOREIGN KEY (inspection_id) REFERENCES public.inspections(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: articles fk_rails_7809a1a57d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_7809a1a57d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: services fk_rails_785ab2e60d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_785ab2e60d FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: training_offerings fk_rails_78ee1867f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT fk_rails_78ee1867f5 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: case_studies fk_rails_790537e2c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT fk_rails_790537e2c2 FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: assignments fk_rails_7a0906be01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_7a0906be01 FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: public_resources fk_rails_7a5cbabb49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT fk_rails_7a5cbabb49 FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: permission_overrides fk_rails_7e69c157cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_overrides
    ADD CONSTRAINT fk_rails_7e69c157cf FOREIGN KEY (granted_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspections fk_rails_7ee07318d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_7ee07318d5 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: projects fk_rails_7f51c5737c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_7f51c5737c FOREIGN KEY (quote_response_id) REFERENCES public.quote_responses(id);


--
-- Name: document_access_grants fk_rails_7fad973732; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants
    ADD CONSTRAINT fk_rails_7fad973732 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: invoice_line_items fk_rails_80427eb9d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT fk_rails_80427eb9d3 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: inspection_evidence_links fk_rails_80615e21e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links
    ADD CONSTRAINT fk_rails_80615e21e0 FOREIGN KEY (document_version_id) REFERENCES public.document_versions(id);


--
-- Name: inspection_evidence_links fk_rails_80722701ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links
    ADD CONSTRAINT fk_rails_80722701ab FOREIGN KEY (inspection_id) REFERENCES public.inspections(id);


--
-- Name: service_inquiry_notes fk_rails_81b6480f05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_notes
    ADD CONSTRAINT fk_rails_81b6480f05 FOREIGN KEY (corrects_note_id) REFERENCES public.service_inquiry_notes(id);


--
-- Name: quote_revisions fk_rails_82a8ad8956; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT fk_rails_82a8ad8956 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: assignments fk_rails_82b1433829; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_82b1433829 FOREIGN KEY (assigned_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: projects fk_rails_8333d12366; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_8333d12366 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: project_milestones fk_rails_843f80230e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_milestones
    ADD CONSTRAINT fk_rails_843f80230e FOREIGN KEY (responsible_membership_id) REFERENCES public.memberships(id);


--
-- Name: invoices fk_rails_8442c0a799; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_8442c0a799 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: schedule_events fk_rails_89c18faad2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events
    ADD CONSTRAINT fk_rails_89c18faad2 FOREIGN KEY (responsible_membership_id) REFERENCES public.memberships(id);


--
-- Name: report_releases fk_rails_8ac9a62ab5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_releases
    ADD CONSTRAINT fk_rails_8ac9a62ab5 FOREIGN KEY (report_id) REFERENCES public.reports(id);


--
-- Name: inspections fk_rails_8c01baf3b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_8c01baf3b5 FOREIGN KEY (inspection_template_version_id) REFERENCES public.inspection_template_versions(id);


--
-- Name: project_milestones fk_rails_8ea5131e54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_milestones
    ADD CONSTRAINT fk_rails_8ea5131e54 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: quotes fk_rails_92d9cd0628; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_92d9cd0628 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: document_access_grants fk_rails_93a4622de3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants
    ADD CONSTRAINT fk_rails_93a4622de3 FOREIGN KEY (granted_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_releases fk_rails_93f015a9b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_releases
    ADD CONSTRAINT fk_rails_93f015a9b6 FOREIGN KEY (document_version_id) REFERENCES public.document_versions(id);


--
-- Name: service_inquiry_assignments fk_rails_95eee61eba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments
    ADD CONSTRAINT fk_rails_95eee61eba FOREIGN KEY (new_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_access_grants fk_rails_96507fd8d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_access_grants
    ADD CONSTRAINT fk_rails_96507fd8d2 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: document_versions fk_rails_975f9c7128; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_rails_975f9c7128 FOREIGN KEY (uploaded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: reports fk_rails_9a0a9c9bec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_9a0a9c9bec FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: inspection_checklist_responses fk_rails_9d92e2160c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_checklist_responses
    ADD CONSTRAINT fk_rails_9d92e2160c FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: invoice_releases fk_rails_9dc3f69153; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT fk_rails_9dc3f69153 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: tasks fk_rails_9f28c828eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_9f28c828eb FOREIGN KEY (assignee_membership_id) REFERENCES public.memberships(id);


--
-- Name: training_offerings fk_rails_9f8168231e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT fk_rails_9f8168231e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: projects fk_rails_a43a9532f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_a43a9532f1 FOREIGN KEY (coordinator_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_revisions fk_rails_a48db1c661; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT fk_rails_a48db1c661 FOREIGN KEY (prepared_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: invitations fk_rails_a57966c2f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_a57966c2f2 FOREIGN KEY (invited_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: report_versions fk_rails_a653a00b67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions
    ADD CONSTRAINT fk_rails_a653a00b67 FOREIGN KEY (storage_asset_id) REFERENCES public.storage_assets(id);


--
-- Name: public_resources fk_rails_aa198ccc2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT fk_rails_aa198ccc2d FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: assignments fk_rails_aa6b76dac2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_aa6b76dac2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: invoice_releases fk_rails_acc08fdddd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT fk_rails_acc08fdddd FOREIGN KEY (storage_asset_id) REFERENCES public.storage_assets(id);


--
-- Name: invoice_releases fk_rails_ade2bb528f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT fk_rails_ade2bb528f FOREIGN KEY (released_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: case_studies fk_rails_ae2a2e43e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT fk_rails_ae2a2e43e0 FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: storage_assets fk_rails_afad6aac76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_assets
    ADD CONSTRAINT fk_rails_afad6aac76 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: report_versions fk_rails_b1ce893d5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions
    ADD CONSTRAINT fk_rails_b1ce893d5d FOREIGN KEY (submitted_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: client_contacts fk_rails_b52803964e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contacts
    ADD CONSTRAINT fk_rails_b52803964e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: projects fk_rails_b55f8f1c63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_b55f8f1c63 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: public_site_pages fk_rails_b646781e99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT fk_rails_b646781e99 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quote_deliveries fk_rails_b748812030; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT fk_rails_b748812030 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: reports fk_rails_bbe1f0fdf5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_bbe1f0fdf5 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: services fk_rails_bcf4f37ee4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_bcf4f37ee4 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: schedule_events fk_rails_bd6eccad37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_events
    ADD CONSTRAINT fk_rails_bd6eccad37 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: quote_revisions fk_rails_bdb9eb000d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_revisions
    ADD CONSTRAINT fk_rails_bdb9eb000d FOREIGN KEY (submitted_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: audit_events fk_rails_be0ed9e37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_be0ed9e37f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: public_site_pages fk_rails_c25692c0a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT fk_rails_c25692c0a7 FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_responses fk_rails_c2902b3570; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_c2902b3570 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: invoices fk_rails_c369402ca3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_c369402ca3 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: quote_portal_releases fk_rails_c5d2fba065; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT fk_rails_c5d2fba065 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: service_inquiry_assignments fk_rails_c7143bb1b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments
    ADD CONSTRAINT fk_rails_c7143bb1b2 FOREIGN KEY (previous_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_responses fk_rails_c8108f2f08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_responses
    ADD CONSTRAINT fk_rails_c8108f2f08 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: document_versions fk_rails_c81b8ae028; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_rails_c81b8ae028 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: permission_overrides fk_rails_c942e92102; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_overrides
    ADD CONSTRAINT fk_rails_c942e92102 FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: projects fk_rails_ca7db128d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_ca7db128d4 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: public_resources fk_rails_cc2dea2312; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_resources
    ADD CONSTRAINT fk_rails_cc2dea2312 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: documents fk_rails_d15199831d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_d15199831d FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: client_contacts fk_rails_d1a05dd5fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_contacts
    ADD CONSTRAINT fk_rails_d1a05dd5fd FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: document_versions fk_rails_d27d652526; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_rails_d27d652526 FOREIGN KEY (storage_asset_id) REFERENCES public.storage_assets(id);


--
-- Name: case_studies fk_rails_d3d72e44da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT fk_rails_d3d72e44da FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: documents fk_rails_d60c82736e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_d60c82736e FOREIGN KEY (operating_organization_id) REFERENCES public.organizations(id);


--
-- Name: staff_notifications fk_rails_dc9c4ea2c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notifications
    ADD CONSTRAINT fk_rails_dc9c4ea2c3 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: public_site_pages fk_rails_dcae3cb539; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT fk_rails_dcae3cb539 FOREIGN KEY (approved_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quotes fk_rails_de7694c307; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_de7694c307 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quote_portal_releases fk_rails_df75df1687; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT fk_rails_df75df1687 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: service_inquiry_assignments fk_rails_e0dd0e2987; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_assignments
    ADD CONSTRAINT fk_rails_e0dd0e2987 FOREIGN KEY (actor_membership_id) REFERENCES public.memberships(id);


--
-- Name: service_inquiry_clarifications fk_rails_e218ab8492; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT fk_rails_e218ab8492 FOREIGN KEY (withdrawn_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: invoice_releases fk_rails_e32e301758; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT fk_rails_e32e301758 FOREIGN KEY (revoked_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: upload_requests fk_rails_e5a86e017b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_requests
    ADD CONSTRAINT fk_rails_e5a86e017b FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: audit_events fk_rails_e7685dedc6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_e7685dedc6 FOREIGN KEY (actor_membership_id) REFERENCES public.memberships(id);


--
-- Name: quote_deliveries fk_rails_e7b3ac61b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_deliveries
    ADD CONSTRAINT fk_rails_e7b3ac61b9 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: training_offerings fk_rails_eb025cc565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.training_offerings
    ADD CONSTRAINT fk_rails_eb025cc565 FOREIGN KEY (published_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspections fk_rails_eb2ad78932; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspections
    ADD CONSTRAINT fk_rails_eb2ad78932 FOREIGN KEY (assigned_surveyor_membership_id) REFERENCES public.memberships(id);


--
-- Name: articles fk_rails_eb3527c40a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_eb3527c40a FOREIGN KEY (updated_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quotes fk_rails_ed2b09c699; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_ed2b09c699 FOREIGN KEY (service_inquiry_id) REFERENCES public.service_inquiries(id);


--
-- Name: service_inquiry_notes fk_rails_edfbeafc7b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_notes
    ADD CONSTRAINT fk_rails_edfbeafc7b FOREIGN KEY (author_membership_id) REFERENCES public.memberships(id);


--
-- Name: invoice_releases fk_rails_ee064e96b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_releases
    ADD CONSTRAINT fk_rails_ee064e96b0 FOREIGN KEY (client_organization_id) REFERENCES public.organizations(id);


--
-- Name: invoices fk_rails_eeffd1700a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_eeffd1700a FOREIGN KEY (voided_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: quotes fk_rails_f1bc6f676f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_f1bc6f676f FOREIGN KEY (current_revision_id) REFERENCES public.quote_revisions(id);


--
-- Name: invitations fk_rails_f2e11a7816; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_f2e11a7816 FOREIGN KEY (accepted_by_user_id) REFERENCES public.users(id);


--
-- Name: service_inquiry_clarifications fk_rails_f5ead2f2a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiry_clarifications
    ADD CONSTRAINT fk_rails_f5ead2f2a5 FOREIGN KEY (service_inquiry_id) REFERENCES public.service_inquiries(id);


--
-- Name: case_studies fk_rails_f62431e529; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_studies
    ADD CONSTRAINT fk_rails_f62431e529 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: inspection_evidence_links fk_rails_f66572c54b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspection_evidence_links
    ADD CONSTRAINT fk_rails_f66572c54b FOREIGN KEY (finding_id) REFERENCES public.inspection_findings(id);


--
-- Name: public_site_pages fk_rails_f7f635af30; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_site_pages
    ADD CONSTRAINT fk_rails_f7f635af30 FOREIGN KEY (created_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: projects fk_rails_f9f3cae347; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_f9f3cae347 FOREIGN KEY (service_inquiry_id) REFERENCES public.service_inquiries(id);


--
-- Name: payment_records fk_rails_fac1a74bc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_records
    ADD CONSTRAINT fk_rails_fac1a74bc2 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: storage_assets fk_rails_fc20c8e060; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_assets
    ADD CONSTRAINT fk_rails_fc20c8e060 FOREIGN KEY (uploaded_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: service_inquiries fk_rails_fc6c2c9815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_inquiries
    ADD CONSTRAINT fk_rails_fc6c2c9815 FOREIGN KEY (assigned_membership_id) REFERENCES public.memberships(id);


--
-- Name: report_versions fk_rails_fc879b7434; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_versions
    ADD CONSTRAINT fk_rails_fc879b7434 FOREIGN KEY (authored_by_membership_id) REFERENCES public.memberships(id);


--
-- Name: report_reviews fk_rails_fddd4b8641; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_reviews
    ADD CONSTRAINT fk_rails_fddd4b8641 FOREIGN KEY (report_version_id) REFERENCES public.report_versions(id);


--
-- Name: quote_portal_releases fk_rails_fea84cae67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_portal_releases
    ADD CONSTRAINT fk_rails_fea84cae67 FOREIGN KEY (revoked_by_membership_id) REFERENCES public.memberships(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261126221000'),
('20261126220000'),
('20261126210000'),
('20261126200000'),
('20261126195000'),
('20261126190000'),
('20261126180000'),
('20261126150000'),
('20261126140000'),
('20261126120000'),
('20261126020100'),
('20261126020000'),
('20261126010000'),
('20261125230000'),
('20261125220000'),
('20261125210000'),
('20261125200000'),
('20261125190000'),
('20261125180000'),
('20261125170000'),
('20261125090000'),
('20261124143000'),
('20261123143000'),
('20261123141933'),
('20261123120000'),
('20261123010000'),
('20261122224000'),
('20261122223126'),
('20261122120003'),
('20261122120002'),
('20261122120001'),
('20261122120000'),
('20261122103002'),
('20261122103001'),
('20261122103000'),
('20261122092002'),
('20261122092001'),
('20261122092000');

