-- Q6: List all managers across all hotels/chains.
-- Run in terminal:
-- psql -d ehotels -U luuluu2 -f sql/queries/10_q6_list_all_managers.sql
SELECT
  e.employee_id AS manager_employee_id,
  p.legal_id AS manager_sin,
  p.first_name,
  p.last_name,
  p.email,
  p.phone,
  h.hotel_id,
  h.hotel_name,
  hc.chain_id,
  hc.chain_name,
  e.role_title,
  e.hired_on,
  a.username AS account_username,
  a.is_active AS account_is_active
FROM employee e
JOIN person p ON p.legal_id = e.legal_id
JOIN hotel h ON h.hotel_id = e.hotel_id
JOIN hotel_chain hc ON hc.chain_id = h.chain_id
LEFT JOIN auth_account a
  ON a.employee_id = e.employee_id
 AND a.role = 'manager'
WHERE e.is_manager = TRUE
ORDER BY hc.chain_name, h.hotel_name, p.last_name, p.first_name;
