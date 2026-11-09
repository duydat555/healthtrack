-- Đo hiệu quả chỉ mục (issue #63). Chạy trên CSDL thử đã `alembic upgrade head`:
--   docker compose exec -T db psql -U healthtrack -d bench -f - < scripts/bench_indexes.sql
-- Tạo 250 user, mỗi user 2000 bản ghi nước và 2000 bản ghi cân nặng trải trong 2 năm (1 triệu dòng).
\set ON_ERROR_STOP on
\timing off

INSERT INTO users (email, password_hash, full_name)
SELECT 'u' || g || '@bench.local', 'x', 'U' || g FROM generate_series(1, 250) g;

INSERT INTO water_logs (user_id, amount_ml, logged_at)
SELECT u, 100 + (random() * 400)::int, now() - (random() * interval '730 days')
FROM generate_series(1, 250) u, generate_series(1, 2000) i;

INSERT INTO weight_logs (user_id, weight_kg, bmi, logged_at)
SELECT u, 50 + random() * 40, 22, now() - (random() * interval '730 days')
FROM generate_series(1, 250) u, generate_series(1, 2000) i;

ANALYZE;

-- Hàm đo: chạy EXPLAIN ANALYZE 7 lần, trả về thời gian trung vị (ms) và kiểu quét
CREATE OR REPLACE FUNCTION bench(q text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE t numeric[] := '{}'; r json; plan text; i int;
BEGIN
  FOR i IN 1..7 LOOP
    EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || q INTO r;
    t := t || ((r->0->>'Execution Time')::numeric);
  END LOOP;
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY x) INTO plan FROM unnest(t) x;
  RETURN round(plan::numeric, 3) || ' ms | ' ||
         (SELECT string_agg(DISTINCT m[1], ',') FROM regexp_matches(r::text, '"Node Type": "([^"]+)"', 'g') m);
END $$;

\echo '=== SAU (có chỉ mục (user_id, logged_at)) ==='
\echo 'Q1 danh sách 30 ngày gần nhất, 50 dòng (water):'
SELECT bench($$SELECT id, amount_ml, logged_at FROM water_logs WHERE user_id = 77 AND logged_at >= now() - interval '30 days' ORDER BY logged_at DESC, id DESC LIMIT 50$$);
\echo 'Q2 tổng nước trong 1 ngày (water):'
SELECT bench($$SELECT coalesce(sum(amount_ml),0) FROM water_logs WHERE user_id = 77 AND logged_at >= date_trunc('day', now() - interval '10 days') AND logged_at < date_trunc('day', now() - interval '9 days')$$);
\echo 'Q3 xu hướng cân nặng theo ngày, 90 ngày (weight):'
SELECT bench($$SELECT date_trunc('day', logged_at) d, avg(weight_kg) FROM weight_logs WHERE user_id = 77 AND logged_at >= now() - interval '90 days' GROUP BY 1 ORDER BY 1$$);

DROP INDEX ix_water_logs_user_id_logged_at;
DROP INDEX ix_weight_logs_user_id_logged_at;
ANALYZE;

\echo '=== TRƯỚC (không có chỉ mục) ==='
\echo 'Q1:'
SELECT bench($$SELECT id, amount_ml, logged_at FROM water_logs WHERE user_id = 77 AND logged_at >= now() - interval '30 days' ORDER BY logged_at DESC, id DESC LIMIT 50$$);
\echo 'Q2:'
SELECT bench($$SELECT coalesce(sum(amount_ml),0) FROM water_logs WHERE user_id = 77 AND logged_at >= date_trunc('day', now() - interval '10 days') AND logged_at < date_trunc('day', now() - interval '9 days')$$);
\echo 'Q3:'
SELECT bench($$SELECT date_trunc('day', logged_at) d, avg(weight_kg) FROM weight_logs WHERE user_id = 77 AND logged_at >= now() - interval '90 days' GROUP BY 1 ORDER BY 1$$);
