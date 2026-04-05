-- Run in terminal: psql -d ehotels -f sql/queries/01_q1_active_reservations_per_hotel_chain.sql
-- Q1 (Aggregation): Number of active reservations per hotel chain
SELECT
  hc.chain_name,
  COUNT(b.booking_id) AS active_bookings
FROM hotel_chain hc
JOIN hotel h ON h.chain_id = hc.chain_id
JOIN room r ON r.hotel_id = h.hotel_id
LEFT JOIN booking b ON b.room_id = r.room_id AND b.status IN ('reserved', 'checked_in')
GROUP BY hc.chain_name
ORDER BY active_bookings DESC;
