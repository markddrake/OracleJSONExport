set YADMAU_OUTPUT_FOLDER=%1
if exist  %YADMAU_OUTPUT_FOLDER%\JSON\ rmdir /s /q %YADMAU_OUTPUT_FOLDER%\JSON
mkdir %YADMAU_OUTPUT_FOLDER%\JSON
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle19c
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle19c\DDL_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle19c\DATA_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle19c\DDL_AND_DATA
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle18c
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle18c\DDL_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle18c\DATA_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle18c\DDL_AND_DATA
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle12c
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle12c\DDL_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle12c\DATA_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle12c\DDL_AND_DATA
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle11g
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle11g\DDL_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle11g\DATA_ONLY
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\oracle11g\DDL_AND_DATA
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\mssql17
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\mssql19
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\mysql
mkdir %YADMAU_OUTPUT_FOLDER%\JSON\postgres
