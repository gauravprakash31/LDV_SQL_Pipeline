DROP SCHEMA IF EXISTS stage_products CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_products;

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Products",
		"RentalTypes",

		"ProductDynamicControlValues",
		"DynamicControls",
		"DynamicControlOptions",
		"DynamicControlProductMappings",
		"DynamicControlRoleMappings"
	)
	FROM SERVER productsapi_srv INTO stage_products;

ALTER TABLE stage_products."ProductDynamicControlValues" 	RENAME TO product_dynamic_control_values_p;
ALTER TABLE stage_products."DynamicControls" 				RENAME TO dynamic_controls_p;
ALTER TABLE stage_products."DynamicControlOptions" 			RENAME TO dynamic_control_options_p;
ALTER TABLE stage_products."DynamicControlProductMappings" 	RENAME TO dynamic_control_product_mappings_p;
ALTER TABLE stage_products."DynamicControlRoleMappings" 	RENAME TO dynamic_control_role_mappings_p;

