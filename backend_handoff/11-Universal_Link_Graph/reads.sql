-- reads.sql (Universal Link Graph)
-- Read queries for resolving linked records and building the network visualization.

-- 1. Fetch all connected links for a specific record
SELECT 
    id,
    target_kind,
    target_id,
    label,
    metadata,
    created_at
FROM universal_link_edges
WHERE user_id = auth.uid()
  AND source_kind = :source_kind
  AND source_id = :source_id
ORDER BY created_at DESC;

-- 2. Build full graph nodes and edges for strategy / note relationship visualization
SELECT 
    source_kind,
    source_id,
    target_kind,
    target_id,
    label,
    metadata
FROM universal_link_edges
WHERE user_id = auth.uid();
