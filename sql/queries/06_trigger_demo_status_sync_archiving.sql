-- Run in terminal: psql -d ehotels -f sql/queries/06_trigger_demo_status_sync_archiving.sql
-- Trigger demo 2: status sync + archiving
UPDATE booking SET status = 'completed' WHERE booking_id = 3;
UPDATE renting SET status = 'completed' WHERE renting_id = 3;
SELECT * FROM archive ORDER BY archive_id DESC LIMIT 5;
