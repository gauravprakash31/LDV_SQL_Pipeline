DROP SCHEMA IF EXISTS stage_payments CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_payments;

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Partners",
		"PaymentTransactions",
		"PaymentRefund"
	)
	FROM SERVER paymentsapi_srv INTO stage_payments;