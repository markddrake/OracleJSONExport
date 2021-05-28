--
SET SESSION SQL_MODE=ANSI_QUOTES;
--
select concat(DATE_FORMAT(CONVERT_TZ(current_timestamp,@@session.time_zone,'+00:00'),'%Y-%m-%dT%TZ'),': "',@SCHEMA,@ID1,'", "',@SCHEMA,@ID2,'", "',@METHOD,'"') "Timestamp";
--
call COMPARE_SCHEMAS(CONCAT(@SCHEMA,@ID1),CONCAT(@SCHEMA,@ID2),'{"emptyStringisNull": false, "orderedJSON": false, "spatialPrecision: 18}');
--
select  'SUCCESSFUL' "RESULTS", SOURCE_SCHEMA, TARGET_SCHEMA, TABLE_NAME, TARGET_ROW_COUNT
  from SCHEMA_COMPARE_RESULTS 
 where SOURCE_ROW_COUNT = TARGET_ROW_COUNT
   and MISSING_ROWS = 0
   and EXTRA_ROWS = 0
order by TABLE_NAME;
--
select 'FAILED' "RESULTS", SOURCE_SCHEMA, TARGET_SCHEMA, TABLE_NAME, SOURCE_ROW_COUNT, TARGET_ROW_COUNT, MISSING_ROWS, EXTRA_ROWS
  from SCHEMA_COMPARE_RESULTS 
 where SOURCE_ROW_COUNT <> TARGET_ROW_COUNT
    or MISSING_ROWS <> 0
    or EXTRA_ROWS <> 0
 order by TABLE_NAME;
 --