-- First, create the tables if they don't exist
DROP TABLE IF EXISTS U_OrderDetail;
DROP TABLE IF EXISTS U_Order;
CREATE TABLE IF NOT EXISTS U_Order (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    order_date DATE NOT NULL,
    delivery_date DATE,
    total_amount DECIMAL(10, 2)
);

CREATE TABLE IF NOT EXISTS U_OrderDetail (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    line_total DECIMAL(10, 2) NOT NULL
);

-- Create the stored procedure with transaction management
CREATE OR REPLACE PROCEDURE P_process_orders_json(
    IN p_input_json JSONB,
    INOUT p_output_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_order_mapping JSONB;
	v_rows_affected INTEGER;
BEGIN
	--TRUNCATE TABLE U_OrderDetail;
	TRUNCATE TABLE U_Order;

    -- Insert orders from JSON into Order table using set-based operation
    -- The JSON structure expected: {"orders": [...], "orderDetails": [...]}
    WITH inserted_orders AS (
        INSERT INTO U_Order (order_number, customer_name, order_date, delivery_date, total_amount)
        SELECT 
            (order_data->>'order_number')::VARCHAR,
            (order_data->>'customer_name')::VARCHAR,
            (order_data->>'order_date')::DATE,
            (order_data->>'delivery_date')::DATE,
            (order_data->>'total_amount')::DECIMAL
        FROM jsonb_array_elements(p_input_json->'orders') AS order_data
        RETURNING order_id, order_number, delivery_date
    )
    -- Store the inserted order mapping as JSONB
    SELECT jsonb_object_agg(order_number, jsonb_build_object('order_id', order_id, 'delivery_date', delivery_date))
    INTO v_order_mapping
    FROM inserted_orders;

	GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RAISE NOTICE 'Rows affected Order: %', v_rows_affected;

    -- Insert order details from JSON using set-based operation
    INSERT INTO U_OrderDetail (order_id, product_name, quantity, unit_price, line_total)
    SELECT 
        (v_order_mapping->(detail_data->>'order_number')->>'order_id')::INT,
        (detail_data->>'product_name')::VARCHAR,
        (detail_data->>'quantity')::INT,
        (detail_data->>'unit_price')::DECIMAL,
        (detail_data->>'line_total')::DECIMAL
    FROM jsonb_array_elements(p_input_json->'orderDetails') AS detail_data
    WHERE v_order_mapping ? (detail_data->>'order_number');

	GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RAISE NOTICE 'Rows affected OrderDetail: %', v_rows_affected;

    -- Generate JSON output with order number and delivery date per order detail
    SELECT jsonb_agg(
        jsonb_build_object(
            'order_number', o.order_number,
            'delivery_date', o.delivery_date,
            'product_name', det.product_name,
            'quantity', det.quantity,
            'line_total', det.line_total
        )
    )
    INTO p_output_json
    FROM U_OrderDetail det
    	INNER JOIN U_Order o ON det.order_id = o.order_id
    WHERE o.order_number IN (
        SELECT jsonb_object_keys(v_order_mapping)
    );

    -- Return empty array if no output
    IF p_output_json IS NULL THEN
        p_output_json := '[]'::jsonb;
    END IF;
    

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on any error
        ROLLBACK;
        
        -- Re-raise the exception with details
        RAISE EXCEPTION 'Transaction failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$BODY$;

DO $RUN$
DECLARE
    v_output JSONB;
BEGIN
    CALL P_process_orders_json (
    '{
        "orders": [
            {
                "order_number": "ORD-001",
                "customer_name": "John Doe",
                "order_date": "2024-01-15",
                "delivery_date": "2024-01-20",
                "total_amount": 150.00
            },
            {
                "order_number": "ORD-002",
                "customer_name": "Jane Smith",
                "order_date": "2024-01-16",
                "delivery_date": "2024-01-22",
                "total_amount": 275.50
            }
        ],
        "orderDetails": [
            {
                "order_number": "ORD-001",
                "product_name": "Widget A",
                "quantity": 5,
                "unit_price": 10.00,
                "line_total": 50.00
            },
            {
                "order_number": "ORD-001",
                "product_name": "Widget B",
                "quantity": 10,
                "unit_price": 10.00,
                "line_total": 100.00
            },
            {
                "order_number": "ORD-002",
                "product_name": "Widget C",
                "quantity": 15,
                "unit_price": 15.50,
                "line_total": 232.50
            },
            {
                "order_number": "ORD-002",
                "product_name": "Widget D",
                "quantity": 3,
                "unit_price": 14.33,
                "line_total": 43.00
            }
        ]
    }'::jsonb,
    v_output
    );

    -- Display the output
    RAISE NOTICE 'Output: %', v_output;
END 
$RUN$;

SELECT * FROM U_Order;
SELECT * FROM U_OrderDetail;





