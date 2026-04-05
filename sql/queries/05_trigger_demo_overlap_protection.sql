-- Run in terminal: psql -d ehotels -f sql/queries/05_trigger_demo_overlap_protection.sql
-- Trigger demo 1: overlap protection (should fail)
INSERT INTO booking (room_id, customer_id, created_by_employee_id, start_date, end_date, status)
VALUES (5, 25, 1, CURRENT_DATE + 6, CURRENT_DATE + 7, 'reserved');
