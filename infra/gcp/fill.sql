-- An audit table without retention: the "cause" of the full disk.
CREATE TABLE IF NOT EXISTS audit_log (
  id         bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now() - (random() * interval '400 days'),
  payload    text NOT NULL
);

-- ~1 KB per row; 1M rows ≈ 1 GB. Uncompressible (md5 noise).
CREATE OR REPLACE FUNCTION fill_batch(n int) RETURNS void LANGUAGE sql AS $$
  INSERT INTO audit_log (payload)
  SELECT repeat(md5(random()::text), 30) FROM generate_series(1, n);
$$;
