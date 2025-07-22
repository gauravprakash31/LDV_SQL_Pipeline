DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- orders
CREATE SERVER ordersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'orders_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER ordersapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

-- products
CREATE SERVER productsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'products_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER productsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

-- locations
CREATE SERVER locationsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'locations_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER locationsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

-- payments
CREATE SERVER paymentsapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'payments_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER paymentsapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');

-- users
CREATE SERVER usersapi_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS(host 'localhost', port '5432', dbname 'users_db');

CREATE USER MAPPING FOR CURRENT_USER
SERVER usersapi_srv
OPTIONS(user 'postgres', password 'Sharvari04');
