CREATE OR REPLACE PACKAGE TEST_APEX AS
    /*
    Used DB Owner
    */
    C_OWNER VARCHAR2(20) := '<MY DB SCHEMA>';
    /*
    Comma separated list of app id's to check
    */
    C_APPS VARCHAR2(4000) := '<APP_ID1>,<APP_ID2>';
    /*
    Use APEX Workspace name
    */
    C_WORKSPACE VARCHAR2(100) := '<MY_APEX_WORKSPACE>';

      --%suite(TEST APEX Application )
      --%rollback(manual)
    TYPE T_MSSIED_ITEMS IS RECORD (
            APP_ID      NUMBER,
            PAGE_ID     NUMBER,
            REGION_NAME VARCHAR2(4000),
            MSSING_ITEM VARCHAR2(4000)
    );
    TYPE T_MSSIED_ITEMS_TAB IS
        TABLE OF T_MSSIED_ITEMS;


    /*********************************************************
    ** function to generate or attach an apex session
    ** P_IN_APP_ID the app id
    ** P_IN_PAGE_ID the page id 
    ** is P_IN_SESSION is entered the session id is used else a new session is created
    ** P_IN_USERNAME  the user name 
    ** P_OUT_CUR_SESSION the current session id
    *********************************************************/

    PROCEDURE CONNECT_APEX (
        P_IN_APP_ID       NUMBER,
        P_IN_PAGE_ID      NUMBER,
        P_IN_SESSION      NUMBER,
        P_IN_USERNAME     VARCHAR2 DEFAULT NULL,
        P_OUT_CUR_SESSION OUT NUMBER
    );

    /*********************************************************
    ** attach to an existing session via  entered url
    ** P_IN_URL - a non friendly url with APP_ID to parse 
    *********************************************************/

    PROCEDURE CONNECT_APEX (
        P_IN_URL VARCHAR2
    );    

    /*********************************************************
    ** Helper function to generate an apex session
    ** P_APP_ID, P_APP_USER, P_APP_PAGE_ID must exist
    ** (depricated) please use the CONNECT_APEX function
    *********************************************************/
    PROCEDURE GENERATE_APEX_SESSION (
        P_APP_ID      APEX_APPLICATIONS.APPLICATION_ID%TYPE := C_APPS,
        P_APP_USER    APEX_WORKSPACE_ACTIVITY_LOG.APEX_USER%TYPE := 'USER_NAME',
        P_APP_PAGE_ID APEX_APPLICATION_PAGES.PAGE_ID%TYPE := 101
    );

    /*********************************************************
    ** Helper function to return  the missed page items to submit
    ** P_IN_WORKSPACE     : the workspace 
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID          : the Page Id,
    *********************************************************/
    FUNCTION GET_MISSED_ITEMS_2_SUBMIT (
        P_IN_WORKSPACE VARCHAR2,
        P_IN_APP_ID    NUMBER,
        P_IN_PAGE_ID   NUMBER := NULL
    ) RETURN T_MSSIED_ITEMS_TAB
        PIPELINED;
        
    /*********************************************************
    ** Gets the data of a sql from apex page with the bindings. 
    **         
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID          : the Page Id,
    ** P_IN_SQL           : the statment to fetch
    ** P_IN_BINDINGS_JSON : the binding parameters as json array with the elements binding = the name of the page item and value the value to set e.g.
        '[
            {
                "binding" : "P0_TZ_OFFSET",
                "value":"2"
            }        
         ]'
    ** P_IN_SESSION      : the session is used to attach an existing session  if session id is null a new session with the user name is created
    ** P_IN_USERNAME     : the user name - is used when create a new session
    *********************************************************/

    FUNCTION RUN_APEX_SELECT (
        P_IN_APP_ID   NUMBER,
        P_IN_PAGE_ID  NUMBER,
        P_IN_SQL      CLOB,
        P_IN_SESSION  NUMBER DEFAULT NULL,
        P_IN_USERNAME VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    /*********************************************************
    ** Gets the data of a region source from apex page with the bindings
    ** P_IN_WORKSPACE     : the workspace 
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID       : the Page Id,
    ** P_IN_REGION_NAME   : name of the region,
    ** P_IN_BINDINGS_JSON : the binding parameters as json array with the elements binding = the name of the page item and value the value to set e.g.
    ** '[
    **   {
    **     "binding" : "P0_TZ_OFFSET",
    **     "value":"2"
    **    }        
    ** ]'
    ** P_IN_SESSION      : the session is used to attach an existing session  if session id is null a new session with the user name is created
    ** P_IN_USERNAME     : the user name - is used when create a new session
    *********************************************************/

    FUNCTION GET_REGION_SOURCE (
        P_IN_WORKSPACE     VARCHAR2,
        P_IN_APP_ID        NUMBER,
        P_IN_PAGE_ID       NUMBER,
        P_IN_REGION_NAME   VARCHAR2,
        P_IN_BINDINGS_JSON CLOB DEFAULT NULL,
        P_IN_SESSION       NUMBER DEFAULT NULL,
        P_IN_USERNAME      VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;  

     /*********************************************************
    ** get the bindings for the region source
    ** P_IN_WORKSPACE     : the workspace 
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID       : the Page Id
    ** P_IN_REGION_NAME   : name of the region
    ** return             : the binding json  
    *********************************************************/

    FUNCTION GET_REGION_SOURCE_BINDINGS (
        P_IN_WORKSPACE   VARCHAR2,
        P_IN_APP_ID      NUMBER,
        P_IN_PAGE_ID     NUMBER,
        P_IN_REGION_NAME VARCHAR2
    ) RETURN CLOB;
    
    /*********************************************************
    ** get the sql statment to fetch a reagion
    ** P_IN_WORKSPACE     : the workspace 
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID       : the Page Id
    ** P_IN_REGION_NAME   : name of the region
    ** P_IN_BINDINGS_JSON : the binding json  
    ** return             : the sql statment   
    *********************************************************/
    FUNCTION GET_REGION_PREPARED_SQL (
        P_IN_WORKSPACE     VARCHAR2,
        P_IN_APP_ID        NUMBER,
        P_IN_PAGE_ID       NUMBER,
        P_IN_REGION_NAME   VARCHAR2,
        P_IN_BINDINGS_JSON CLOB DEFAULT NULL
    ) RETURN CLOB;
    
    /********************************************************
    ** helper to print out the sys_refcursor
    ** P_IN_CURSOR        :a sys_refcursor
    *********************************************************/
    PROCEDURE SYS_REFCURSOR_TO_TABLE (
        P_IN_CURSOR SYS_REFCURSOR
    );

    /*********************************************************
    ** tests the itemes to submit
    *********************************************************/
    --%test(ITEMS_2_SUBMIT)
    PROCEDURE ITEMS_2_SUBMIT (
        P_IN_APPS      VARCHAR2 DEFAULT C_APPS,
        P_IN_WORKSPACE VARCHAR2 DEFAULT C_WORKSPACE
    );



END TEST_APEX;
/


CREATE OR REPLACE PACKAGE BODY TEST_APEX AS    
    
    /*********************************************************
    **HELPER  GET_BINDS from wwv_flow_utilities to parse the bindings
    *********************************************************/
    FUNCTION GET_BINDS (
        P_STMT IN CLOB
    ) RETURN SYS.DBMS_SQL.VARCHAR2_TABLE AS

        L_STATEMENT                CLOB := P_STMT;
        L_BLOCK_COMMENT_START_POS  PLS_INTEGER;
        L_LINE_COMMENT_START_POS   PLS_INTEGER;
        L_STRING_LITERAL_START_POS PLS_INTEGER;
        L_Q_QUOTE_CHAR             VARCHAR2(1);
        L_CLOSING_TOKEN            VARCHAR2(2);
        L_TOKEN_START_POS          PLS_INTEGER;
        L_TOKEN_END_POS            PLS_INTEGER;
        L_START_SEARCH_POS         PLS_INTEGER;
        L_BIND_START_POS           PLS_INTEGER;
        L_NAME                     VARCHAR2(255);
        L_LENGTH                   PLS_INTEGER;
        L_CHAR                     VARCHAR2(2);
        L_ADDED_BINDS              VARCHAR2(32767) := ':';
        L_BINDS                    SYS.DBMS_SQL.VARCHAR2_TABLE;
    BEGIN
        IF L_STATEMENT IS NULL OR INSTR(
            L_STATEMENT,
            ':'
        ) = 0 THEN
            RETURN L_BINDS;
        END IF;

        L_START_SEARCH_POS := 1;
        LOOP
            L_BLOCK_COMMENT_START_POS  := INSTR(
                L_STATEMENT,
                '/*',
                L_START_SEARCH_POS
            );
            L_LINE_COMMENT_START_POS   := INSTR(
                L_STATEMENT,
                '--',
                L_START_SEARCH_POS
            );
            L_STRING_LITERAL_START_POS := INSTR(
                L_STATEMENT,
                '''',
                L_START_SEARCH_POS
            );
            IF L_BLOCK_COMMENT_START_POS = 0 THEN
                L_BLOCK_COMMENT_START_POS := 999999999;
            END IF;
            IF L_LINE_COMMENT_START_POS = 0 THEN
                L_LINE_COMMENT_START_POS := 999999999;
            END IF;
            IF L_STRING_LITERAL_START_POS = 0 THEN
                L_STRING_LITERAL_START_POS := 999999999;
            END IF;
            IF
                L_STRING_LITERAL_START_POS < L_BLOCK_COMMENT_START_POS
                AND L_STRING_LITERAL_START_POS < L_LINE_COMMENT_START_POS
            THEN
                L_TOKEN_START_POS := L_STRING_LITERAL_START_POS;
                IF UPPER(SUBSTR(
                    L_STATEMENT,
                    L_TOKEN_START_POS - 1,
                    1
                )) = 'Q' THEN
                    L_Q_QUOTE_CHAR     := SUBSTR(
                        L_STATEMENT,
                        L_TOKEN_START_POS + 1,
                        1
                    );
                    L_CLOSING_TOKEN    := CASE L_Q_QUOTE_CHAR
                        WHEN '[' THEN
                            ']'
                        WHEN '{' THEN
                            '}'
                        WHEN '<' THEN
                            '>'
                        WHEN '(' THEN
                            ')'
                        ELSE L_Q_QUOTE_CHAR
                    END ||
                    '''';

                    L_TOKEN_START_POS  := L_TOKEN_START_POS - 1;
                    L_START_SEARCH_POS := L_TOKEN_START_POS + 3;
                ELSE
                    L_CLOSING_TOKEN    := '''';
                    L_START_SEARCH_POS := L_TOKEN_START_POS + 1;
                END IF;

            ELSIF
                L_BLOCK_COMMENT_START_POS < L_LINE_COMMENT_START_POS
                AND L_BLOCK_COMMENT_START_POS < L_STRING_LITERAL_START_POS
            THEN
                L_TOKEN_START_POS  := L_BLOCK_COMMENT_START_POS;
                L_START_SEARCH_POS := L_TOKEN_START_POS + 2;
                L_CLOSING_TOKEN    := '*/';
            ELSIF
                L_LINE_COMMENT_START_POS < L_BLOCK_COMMENT_START_POS
                AND L_LINE_COMMENT_START_POS < L_STRING_LITERAL_START_POS
            THEN
                L_TOKEN_START_POS  := L_LINE_COMMENT_START_POS;
                L_START_SEARCH_POS := L_TOKEN_START_POS + 2;
                L_CLOSING_TOKEN    := WWV_FLOW.LF;
            ELSE
                L_TOKEN_START_POS := NULL;
            END IF;

            EXIT WHEN L_TOKEN_START_POS IS NULL;
            LOOP
                L_TOKEN_END_POS := INSTR(
                    L_STATEMENT,
                    L_CLOSING_TOKEN,
                    L_START_SEARCH_POS
                );
                IF
                    L_TOKEN_END_POS = 0
                    AND L_CLOSING_TOKEN = WWV_FLOW.LF
                THEN
                    L_TOKEN_END_POS := LENGTH(L_STATEMENT);
                    EXIT;
                ELSIF L_TOKEN_END_POS = 0 THEN
                    EXIT;
                ELSIF
                    L_CLOSING_TOKEN = ''''
                    AND SUBSTR(
                        L_STATEMENT,
                        L_TOKEN_END_POS + 1,
                        1
                    ) = ''''
                THEN
                    L_START_SEARCH_POS := L_TOKEN_END_POS + 2;
                ELSE
                    EXIT;
                END IF;

            END LOOP;

            IF L_TOKEN_END_POS > 0 THEN
                L_STATEMENT        := SUBSTR(
                    L_STATEMENT,
                    1,
                    L_TOKEN_START_POS - 1
                ) ||
                SUBSTR(
                    L_STATEMENT,
                    L_TOKEN_END_POS + LENGTH(L_CLOSING_TOKEN)
                );

                L_START_SEARCH_POS := L_TOKEN_START_POS;
            ELSE
                EXIT;
            END IF;

        END LOOP;

        LOOP
            L_BIND_START_POS := NVL(
                INSTR(
                    L_STATEMENT,
                    ':'
                ),
                0
            );
            EXIT WHEN ( L_BIND_START_POS = 0 );
            IF SUBSTR(
                L_STATEMENT,
                L_BIND_START_POS + 1,
                1
            ) <> '"' THEN
                L_NAME   := UPPER(SUBSTR(
                    L_STATEMENT,
                    L_BIND_START_POS,
                    31
                ));
                L_LENGTH := LENGTH(L_NAME);
                FOR J IN 2..L_LENGTH LOOP
                    L_CHAR := SUBSTR(
                        L_NAME,
                        J,
                        1
                    );
                    IF (
                        L_CHAR NOT BETWEEN 'A' AND 'Z'
                        AND L_CHAR NOT BETWEEN '0' AND '9'
                        AND L_CHAR NOT IN (
                            '_',
                            '$',
                            '#'
                        )
                    ) THEN
                        L_NAME := SUBSTR(
                            L_NAME,
                            1,
                            J - 1
                        );
                        EXIT;
                    END IF;

                END LOOP;

            ELSE
                L_NAME := SUBSTR(
                    L_STATEMENT,
                    L_BIND_START_POS + 2,
                    31
                );
                L_NAME := UPPER(SUBSTR(
                    L_NAME,
                    1,
                    INSTR(
                        L_NAME,
                        '"'
                    ) - 1
                ));

                IF
                    L_NAME IS NOT NULL
                    AND ( INSTR(
                        L_NAME,
                        WWV_FLOW.LF
                    ) > 0 OR INSTR(
                        L_NAME,
                        WWV_FLOW.CR
                    ) > 0 OR INSTR(
                        L_NAME,
                        ':'
                    ) > 0 )
                THEN
                    L_NAME := NULL;
                ELSE
                    L_NAME := ':' || L_NAME;
                END IF;

            END IF;

            IF
                LENGTH(L_NAME) > 1
                AND INSTR(
                    L_ADDED_BINDS,
                    L_NAME || ':'
                ) = 0
            THEN
                L_ADDED_BINDS              := L_NAME || L_ADDED_BINDS;
                L_BINDS(L_BINDS.COUNT + 1) := L_NAME;
            END IF;

            L_STATEMENT      := SUBSTR(
                L_STATEMENT,
                L_BIND_START_POS + 1
            );
        END LOOP;

        RETURN L_BINDS;
    END GET_BINDS;

    /*********************************************************
    ** Get the Binding JSON for an sql statment
    *********************************************************/
    FUNCTION GET_BINDINGS (
        P_IN_SQL CLOB
    ) RETURN VARCHAR2 AS
        VR_BIND_NAMES SYS.DBMS_SQL.VARCHAR2_TABLE;
        VR_BINDINGS   VARCHAR2(10000);
    BEGIN
        VR_BIND_NAMES := GET_BINDS(P_IN_SQL);
        SELECT
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    KEY 'binding' IS COLUMN_VALUE,
                    KEY 'value' IS ''
                )
            )
        INTO VR_BINDINGS
        FROM
            TABLE ( VR_BIND_NAMES );

        RETURN VR_BINDINGS;
    END;

    /*********************************************************
    ** function to generate or attach an apex session
    ** P_IN_APP_ID the app id
    ** P_IN_PAGE_ID the page id 
    ** is P_IN_SESSION is entered the session id is used else a new session is created
    ** P_IN_USERNAME  the user name 
    ** P_OUT_CUR_SESSION the current session id
    *********************************************************/

    PROCEDURE CONNECT_APEX (
        P_IN_APP_ID       NUMBER,
        P_IN_PAGE_ID      NUMBER,
        P_IN_SESSION      NUMBER,
        P_IN_USERNAME     VARCHAR2 DEFAULT NULL,
        P_OUT_CUR_SESSION OUT NUMBER
    ) AS
    BEGIN
        IF P_IN_SESSION IS NULL THEN
            APEX_SESSION.CREATE_SESSION(
                P_APP_ID   => P_IN_APP_ID,
                P_PAGE_ID  => P_IN_PAGE_ID,
                P_USERNAME => P_IN_USERNAME
            );
        ELSE
            FOR I IN (
                SELECT
                    1
                FROM
                    DUAL
                WHERE
                    V('SESSION') IS NULL
                    OR P_IN_SESSION != V('SESSION')
            ) LOOP
                APEX_SESSION.ATTACH(
                    P_APP_ID     => P_IN_APP_ID,
                    P_PAGE_ID    => P_IN_PAGE_ID,
                    P_SESSION_ID => P_IN_SESSION
                );
            END LOOP;
        END IF;

        P_OUT_CUR_SESSION := V('SESSION');
    END;

     /*********************************************************
    ** attach to an existing session via  entered url
    *********************************************************/

    PROCEDURE CONNECT_APEX (
        P_IN_URL VARCHAR2
    ) AS
        VR_APP_ID      NUMBER;
        VR_PAGE_ID     NUMBER;
        VR_SESSION_ID  NUMBER;
        VR_CUR_SESSION NUMBER;
    BEGIN
        SELECT
            MIN(APP_ID) APP_ID,
            MIN(PAGE_ID) PAGE_ID,
            MIN(SESSION_ID) SESSION_ID
        INTO
            VR_APP_ID,
            VR_PAGE_ID,
            VR_SESSION_ID
        FROM
            (
                SELECT
                    CASE
                        WHEN ROWNUM = 2 THEN
                            TO_NUMBER(SUBSTR(
                                COLUMN_VALUE,
                                INSTR(
                                    COLUMN_VALUE,
                                    'f?p=',
                                    - 1,
                                    1
                                ) + 4
                            ))
                        ELSE
                            NULL
                    END APP_ID,
                    CASE
                        WHEN ROWNUM = 3 THEN
                            TO_NUMBER(COLUMN_VALUE)
                        ELSE
                            NULL
                    END PAGE_ID,
                    CASE
                        WHEN ROWNUM = 4 THEN
                            TO_NUMBER(COLUMN_VALUE)
                        ELSE
                            NULL
                    END SESSION_ID
                FROM
                    TABLE ( APEX_STRING.SPLIT(
                        P_IN_URL,
                        ':'
                    ) )
            );

        CONNECT_APEX(
            P_IN_APP_ID       => VR_APP_ID,
            P_IN_PAGE_ID      => VR_PAGE_ID,
            P_IN_SESSION      => VR_SESSION_ID,
            P_OUT_CUR_SESSION => VR_CUR_SESSION
        );

    END;

     /*********************************************************
    ** Helper function to generate an apex session
    ** P_APP_ID, P_APP_USER, P_APP_PAGE_ID must exist
    ** (depricated) please use the CONNECT_APEX function
    *********************************************************/

    PROCEDURE GENERATE_APEX_SESSION (
        P_APP_ID      APEX_APPLICATIONS.APPLICATION_ID%TYPE := C_APPS,
        P_APP_USER    APEX_WORKSPACE_ACTIVITY_LOG.APEX_USER%TYPE := 'USER_NAME',
        P_APP_PAGE_ID APEX_APPLICATION_PAGES.PAGE_ID%TYPE := 101
    ) AS
        VR_SESSION_ID  NUMBER;
        VR_CUR_SESSION NUMBER;
    BEGIN
        CONNECT_APEX(
            P_IN_APP_ID       => P_APP_ID,
            P_IN_PAGE_ID      => P_APP_PAGE_ID,
            P_IN_USERNAME     => P_APP_USER,
            P_IN_SESSION      => VR_SESSION_ID,
            P_OUT_CUR_SESSION => VR_CUR_SESSION
        );
    END;

    /*********************************************************
    ** Helper function to return  the missed page items to submit
    ** P_IN_WORKSPACE     : the workspace 
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE_ID          : the Page Id,
    *********************************************************/

    FUNCTION GET_MISSED_ITEMS_2_SUBMIT (
        P_IN_WORKSPACE VARCHAR2,
        P_IN_APP_ID    NUMBER,
        P_IN_PAGE_ID   NUMBER
    ) RETURN T_MSSIED_ITEMS_TAB
        PIPELINED
    AS

        VR_BIND_NAMES SYS.DBMS_SQL.VARCHAR2_TABLE;
        VR_MISSING    APEX_T_VARCHAR2;
        VR_CNT        NUMBER := 0;
        L_ROW_BUF     T_MSSIED_ITEMS;
        I             PLS_INTEGER := 1;
    BEGIN
        FOR REC IN (
            SELECT
                REGION_NAME,
                APPLICATION_ID,
                PAGE_ID,
                REGION_SOURCE,
                AJAX_ITEMS_TO_SUBMIT
            FROM
                APEX_APPLICATION_PAGE_REGIONS
            WHERE
                WORKSPACE = P_IN_WORKSPACE
                AND APPLICATION_ID = P_IN_APP_ID
                AND ( PAGE_ID = P_IN_PAGE_ID
                      OR P_IN_PAGE_ID IS NULL )
                AND SOURCE_TYPE_CODE NOT IN (
                    'STATIC_TEXT',
                    'STATIC_TEXT_ESCAPE_SC',
                    'PLSQL_PROCEDURE',
                    'STATIC_TEXT_WITH_SHORTCUTS',
                    'JSTREE'
                )
        ) LOOP
            VR_BIND_NAMES := GET_BINDS(REC.REGION_SOURCE);
            FOR I IN 1..VR_BIND_NAMES.COUNT LOOP
                IF VR_BIND_NAMES(I) NOT IN (
                    ':APP_USER',
                    ':APP_PAGE_ID',
                    ':APP_ID',
                    ':APP_ALIAS',
                    ':DEBUG',
                    ':APP_SESSION',
                    ':SESSION_ID',
                    ':PRINTER_FRIENDLY'
                ) THEN
                    SELECT
                        COUNT(*)
                    INTO VR_CNT
                    FROM
                        DUAL
                    WHERE
                        EXISTS (
                            SELECT
                                1
                            FROM
                                TABLE ( APEX_STRING.SPLIT(
                                    REC.AJAX_ITEMS_TO_SUBMIT,
                                    ','
                                ) )
                            WHERE
                                COLUMN_VALUE = LTRIM(
                                    VR_BIND_NAMES(I),
                                    ':'
                                )
                        );

                    IF VR_CNT = 0 THEN
                        APEX_STRING.PUSH(
                            VR_MISSING,
                            VR_BIND_NAMES(I)
                        );
                    END IF;

                END IF;
            END LOOP;

            IF LENGTH(APEX_STRING.JOIN(VR_MISSING)) > 0 THEN
                FOR REC_M IN (
                    SELECT
                        COLUMN_VALUE
                    FROM
                        TABLE ( VR_MISSING )
                    WHERE
                        COLUMN_VALUE NOT IN ( ':APP_ALIAS' )
                ) LOOP
                    L_ROW_BUF.APP_ID      := REC.APPLICATION_ID;
                    L_ROW_BUF.PAGE_ID     := REC.PAGE_ID;
                    L_ROW_BUF.REGION_NAME := REC.REGION_NAME;
                    L_ROW_BUF.MSSING_ITEM := REC_M.COLUMN_VALUE;
                    PIPE ROW ( L_ROW_BUF );
                END LOOP;
            END IF;

            VR_MISSING    := NULL;
        END LOOP;

        RETURN;
    END GET_MISSED_ITEMS_2_SUBMIT;

    /*********************************************************
    ** Gets the data of a sql from apex page with the bindings. 
    **         
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE          : the Page Id,
    ** P_IN_SQL           : the statment to fetch
    ** P_IN_BINDINGS_JSON : the binding parameters as json array with the elements binding = the name of the page item and value the value to set e.g.
        '[
            {
                "binding" : "P0_TZ_OFFSET",
                "value":"2"
            }        
         ]'
    ** P_IN_SESSION      : the session is used to attach an existing session  if session id is null a new session with the user name is created
    ** P_IN_USERNAME     : the user name - is used when create a new session
    *********************************************************/

    FUNCTION RUN_APEX_SELECT (
        P_IN_APP_ID   NUMBER,
        P_IN_PAGE_ID  NUMBER,
        P_IN_SQL      CLOB,
        P_IN_SESSION  NUMBER DEFAULT NULL,
        P_IN_USERNAME VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR AS
        VR_CURSOR_NAME INTEGER;
        VR_ROW_COUNT   INTEGER;
        VR_CUR_SESSION NUMBER;
    BEGIN
        VR_CURSOR_NAME := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(
            VR_CURSOR_NAME,
            P_IN_SQL,
            DBMS_SQL.NATIVE
        );
        VR_ROW_COUNT   := DBMS_SQL.EXECUTE(VR_CURSOR_NAME);
        RETURN DBMS_SQL.TO_REFCURSOR(VR_CURSOR_NAME);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_SQL.CLOSE_CURSOR(VR_CURSOR_NAME);
            RAISE;
    END;
    
    /*********************************************************
    ** used to replace the bindings with V variables and sets the 
    ** APEX session states
    ** P_IN_SQL             : the statement to fetch
    ** P_IN_BINDINGS_JSON   : the bindings
    *********************************************************/

    FUNCTION SET_APEX_V_VARIABLES (
        P_IN_SQL           CLOB,
        P_IN_BINDINGS_JSON CLOB
    ) RETURN CLOB AS
        VR_SQL CLOB DEFAULT P_IN_SQL;
    BEGIN
        VR_SQL := REPLACE(
            VR_SQL,
            ':APP_USER',
            'V(''APP_USER'')'
        );
        VR_SQL := REPLACE(
            VR_SQL,
            ':APP_ID',
            'V(''APP_ID'')'
        );
        IF P_IN_BINDINGS_JSON IS NOT NULL THEN
            FOR I IN (
                SELECT
                    *
                FROM
                        JSON_TABLE ( P_IN_BINDINGS_JSON, '$[*]'
                            COLUMNS (
                                BINDING VARCHAR2 ( 500 ) PATH '$.binding',
                                VALUE VARCHAR2 ( 500 ) PATH '$.value'
                            )
                        )
                    J
            ) LOOP
                VR_SQL := REPLACE(
                    VR_SQL,
                    ':' || I.BINDING,
                    'V(''' ||
                    I.BINDING || ''')'
                );

                APEX_UTIL.SET_SESSION_STATE(
                    I.BINDING,
                    I.VALUE
                );
            END LOOP;
        END IF;

        VR_SQL := RTRIM(
            TRIM(VR_SQL),
            '; ' || CHR(10)
        );

        RETURN VR_SQL;
    END;

    /*********************************************************
    ** Get the SQL for a region source
    *********************************************************/

    FUNCTION GET_REGION_SOURCE_SQL (
        P_IN_WORKSPACE   VARCHAR2,
        P_IN_APP_ID      NUMBER,
        P_IN_PAGE_ID     NUMBER,
        P_IN_REGION_NAME VARCHAR2
    ) RETURN CLOB AS
        VR_SQL CLOB;
    BEGIN
        SELECT
            REGION_SOURCE
        INTO VR_SQL
        FROM
            APEX_APPLICATION_PAGE_REGIONS
        WHERE
            WORKSPACE = P_IN_WORKSPACE
            AND APPLICATION_ID = P_IN_APP_ID
            AND PAGE_ID        = P_IN_PAGE_ID
            AND REGION_NAME    = P_IN_REGION_NAME
            AND SOURCE_TYPE_CODE NOT IN (
                'STATIC_TEXT',
                'STATIC_TEXT_ESCAPE_SC',
                'PLSQL_PROCEDURE',
                'STATIC_TEXT_WITH_SHORTCUTS',
                'JSTREE'
            );

        RETURN VR_SQL;
    END;

    FUNCTION GET_REGION_PREPARED_SQL (
        P_IN_WORKSPACE     VARCHAR2,
        P_IN_APP_ID        NUMBER,
        P_IN_PAGE_ID       NUMBER,
        P_IN_REGION_NAME   VARCHAR2,
        P_IN_BINDINGS_JSON CLOB DEFAULT NULL
    ) RETURN CLOB AS
        VR_SQL CLOB;
    BEGIN
        VR_SQL := GET_REGION_SOURCE_SQL(
            P_IN_WORKSPACE   => P_IN_WORKSPACE,
            P_IN_APP_ID      => P_IN_APP_ID,
            P_IN_PAGE_ID     => P_IN_PAGE_ID,
            P_IN_REGION_NAME => P_IN_REGION_NAME
        );

        IF P_IN_BINDINGS_JSON IS NOT NULL THEN
            VR_SQL := SET_APEX_V_VARIABLES(
                P_IN_SQL           => VR_SQL,
                P_IN_BINDINGS_JSON => P_IN_BINDINGS_JSON
            );
        END IF;

        RETURN VR_SQL;
    END;    

    /*********************************************************
    ** Gets the data of a region source from apex page with the bindings
    **  
    ** P_IN_APP_ID        : the App Id 
    ** P_IN_PAGE          : the Page Id,
    ** P_IN_REGION_NAME   : name of the region,
    ** P_IN_BINDINGS_JSON : the binding parameters as json array with the elements binding = the name of the page item and value the value to set e.g.
    ** '[
    **   {
    **     "binding" : "P0_TZ_OFFSET",
    **     "value":"2"
    **    }        
    ** ]'
    ** P_IN_SESSION      : the session is used to attach an existing session  if session id is null a new session with the user name is created
    ** P_IN_USERNAME     : the user name - is used when create a new session
    *********************************************************/

    FUNCTION GET_REGION_SOURCE (
        P_IN_WORKSPACE     VARCHAR2,
        P_IN_APP_ID        NUMBER,
        P_IN_PAGE_ID       NUMBER,
        P_IN_REGION_NAME   VARCHAR2,
        P_IN_BINDINGS_JSON CLOB DEFAULT NULL,
        P_IN_SESSION       NUMBER DEFAULT NULL,
        P_IN_USERNAME      VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR AS
        VR_SQL     CLOB;
        VR_SESSION NUMBER;
    BEGIN
        CONNECT_APEX(
            P_IN_APP_ID       => P_IN_APP_ID,
            P_IN_PAGE_ID      => P_IN_PAGE_ID,
            P_IN_SESSION      => P_IN_SESSION,
            P_IN_USERNAME     => P_IN_USERNAME,
            P_OUT_CUR_SESSION => VR_SESSION
        );

        VR_SQL := GET_REGION_PREPARED_SQL(
            P_IN_WORKSPACE     => P_IN_WORKSPACE,
            P_IN_APP_ID        => P_IN_APP_ID,
            P_IN_PAGE_ID       => P_IN_PAGE_ID,
            P_IN_REGION_NAME   => P_IN_REGION_NAME,
            P_IN_BINDINGS_JSON => P_IN_BINDINGS_JSON
        );

        RETURN RUN_APEX_SELECT(
            P_IN_APP_ID   => P_IN_APP_ID,
            P_IN_PAGE_ID  => P_IN_PAGE_ID,
            P_IN_SQL      => VR_SQL,
            P_IN_USERNAME => P_IN_USERNAME,
            P_IN_SESSION  => P_IN_SESSION
        );

    END;

    PROCEDURE SYS_REFCURSOR_TO_TABLE (
        P_IN_CURSOR SYS_REFCURSOR
    ) IS

        TYPE CURTYPE IS REF CURSOR;
        VR_CUR_ID   PLS_INTEGER;
        VR_COLCOUNT PLS_INTEGER;
        VR_CURSDESC DBMS_SQL.DESC_TAB;
        VR_COLVALUE VARCHAR2(32000);
        VR_CURSOR   SYS_REFCURSOR := P_IN_CURSOR;
    BEGIN
        VR_CUR_ID := DBMS_SQL.TO_CURSOR_NUMBER(VR_CURSOR);
        DBMS_SQL.DESCRIBE_COLUMNS(
            VR_CUR_ID,
            VR_COLCOUNT,
            VR_CURSDESC
        );
       -- RAISE_APPLICATION_ERROR(-20001,vr_cursdesc);
        FOR I IN 1..VR_COLCOUNT LOOP
            DBMS_SQL.DEFINE_COLUMN(
                VR_CUR_ID,
                I,
                VR_COLVALUE,
                4000
            );
            DBMS_OUTPUT.PUT_LINE('   ' || VR_COLVALUE);
        END LOOP;

        WHILE ( DBMS_SQL.FETCH_ROWS(VR_CUR_ID) > 0 ) LOOP
            FOR I IN 1..VR_COLCOUNT LOOP
                DBMS_SQL.COLUMN_VALUE(
                    VR_CUR_ID,
                    I,
                    VR_COLVALUE
                );
                DBMS_OUTPUT.PUT('   ' || VR_COLVALUE);
                
            END LOOP;
                DBMS_OUTPUT.PUT_LINE('     |');
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(VR_CUR_ID);
    END;

     /*********************************************************
    ** get the bindings for the region source
    **  P_IN_APP_ID        : the App Id 
    **  P_IN_PAGE          : the Page Id
    **  P_IN_REGION_NAME   : name of the region
    **  return             : the binding json  
    *********************************************************/

    FUNCTION GET_REGION_SOURCE_BINDINGS (
        P_IN_WORKSPACE   VARCHAR2,
        P_IN_APP_ID      NUMBER,
        P_IN_PAGE_ID     NUMBER,
        P_IN_REGION_NAME VARCHAR2
    ) RETURN CLOB AS
        VR_SQL CLOB;
    BEGIN
        VR_SQL := GET_REGION_SOURCE_SQL(
            P_IN_WORKSPACE   => P_IN_WORKSPACE,
            P_IN_APP_ID      => P_IN_APP_ID,
            P_IN_PAGE_ID     => P_IN_PAGE_ID,
            P_IN_REGION_NAME => P_IN_REGION_NAME
        );

        RETURN GET_BINDINGS(VR_SQL);
    END;


    /*********************************************************
    ** test the page items to submit for an selected app
    *********************************************************/

    PROCEDURE TEST_ITEMS_2SUBMIT (
        P_IN_APP_ID    NUMBER,
        P_IN_WORKSPACE VARCHAR2
    ) AS
        VR_EXCPECTED SYS_REFCURSOR;
        VR_ACTUAL    SYS_REFCURSOR;
    BEGIN
        OPEN VR_EXCPECTED FOR
            SELECT
                1  AS APP_ID,
                1  AS PAGE_ID,
                '' AS REGION_NAME,
                '' AS MSSING_ITEM
            FROM
                DUAL
            WHERE
                1 = 2;

        OPEN VR_ACTUAL FOR
            SELECT
                *
            FROM
                TABLE ( TEST_APEX.GET_MISSED_ITEMS_2_SUBMIT(
                    P_IN_APP_ID    => P_IN_APP_ID,
                    P_IN_WORKSPACE => P_IN_WORKSPACE
                ) );

        UT.EXPECT(
            VR_ACTUAL,
            'APPLICATION_ID: ' || P_IN_APP_ID
        ).TO_(EQUAL(VR_EXCPECTED));

    END;

    /*********************************************************
    ** test for missing items to submit for the selected owner
    *********************************************************/

    PROCEDURE ITEMS_2_SUBMIT (
        P_IN_APPS      VARCHAR2 DEFAULT C_APPS,
        P_IN_WORKSPACE VARCHAR2 DEFAULT C_WORKSPACE
    ) AS
    BEGIN
        FOR I IN (
            SELECT
                TO_NUMBER(TRIM(COLUMN_VALUE)) APPLICATION_ID
            FROM
                TABLE ( APEX_STRING.SPLIT(
                    P_STR => P_IN_APPS,
                    P_SEP => ','
                ) )
        ) LOOP
            TEST_ITEMS_2SUBMIT(
                P_IN_APP_ID    => I.APPLICATION_ID,
                P_IN_WORKSPACE => P_IN_WORKSPACE
            );
        END LOOP;
    END;

END TEST_APEX;
/
