-- Uptime Kuma: copy each monitor's hostname into an "IP" tag.
-- For MariaDB (embedded or external). For SQLite, use add-ip-tags-sqlite.sql.
--
-- 1. Creates the "IP" tag (gray, #6B7280) if it doesn't exist.
-- 2. Tags every monitor that has a hostname but no IP tag.
-- 3. Updates IP tags whose value no longer matches the hostname.
-- 4. Lists every tagged monitor with its IP.
--
-- Monitors without a hostname (HTTP checks, groups) are skipped.
-- Safe to run repeatedly while Kuma is running.

INSERT INTO tag (name, color)
SELECT 'IP', '#6B7280'
WHERE NOT EXISTS (SELECT 1 FROM tag WHERE name = 'IP');

INSERT INTO monitor_tag (monitor_id, tag_id, value)
SELECT m.id, t.id, m.hostname
FROM monitor m
JOIN tag t ON t.name = 'IP'
WHERE m.hostname IS NOT NULL
  AND m.hostname <> ''
  AND NOT EXISTS (
    SELECT 1 FROM monitor_tag mt
    WHERE mt.monitor_id = m.id AND mt.tag_id = t.id
  );

UPDATE monitor_tag mt
JOIN monitor m ON m.id = mt.monitor_id
JOIN tag t ON t.id = mt.tag_id
SET mt.value = m.hostname
WHERE t.name = 'IP'
  AND m.hostname IS NOT NULL
  AND m.hostname <> ''
  AND mt.value <> m.hostname;

SELECT m.name, mt.value
FROM monitor_tag mt
JOIN monitor m ON m.id = mt.monitor_id
JOIN tag t ON t.id = mt.tag_id
WHERE t.name = 'IP'
ORDER BY m.name;
