DROP SCHEMA IF EXISTS stage_users CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_users;

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Users"
	)
	FROM SERVER usersapi_srv INTO stage_users;
