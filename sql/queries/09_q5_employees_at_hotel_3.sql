-- Run in terminal: psql -d ehotels -f sql/queries/09_q5_employees_at_hotel_3.sql
SELECT
  e.employee_id,
  e.legal_id,
  p.first_name,
  p.last_name,
  e.hotel_id,
  e.role_title,
  e.hired_on,
  e.is_manager
FROM employee e
JOIN person p ON p.legal_id = e.legal_id
WHERE e.hotel_id = 3
ORDER BY e.employee_id;
