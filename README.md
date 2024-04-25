# This package is used to test an Oracle APEX App with utPLSQL (https://www.utplsql.org/).

Before import place check and replace the constants.
``` /*
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
```

After import you can directly use the Item2Submit test.

Query an APEX region
is used to query an region from an APEX page.

## 1.) Get the Binding JSONS

```
SELECT TEST_APEX.GET_REGION_SOURCE_BINDINGS(
        P_IN_WORKSPACE   => '<MY WORKSPACE>',
        P_IN_APP_ID      => <APP_ID>,
        P_IN_PAGE_ID     => <PAGE_ID>,
        P_IN_REGION_NAME => '<region name>'
    )
FROM
    DUAL;
```

## 2.) Fill the binding JSON with the test Setting

       Please note the bindings are text in APEX. 
       For date and number you must ensure that the nls setting an the variable syntax matches
       e.g. you can force the NLS settings for all test with ALTER SESSION SET NLS_LANGUAGE=XXXX 
       
## 3.) check the result

```
SET SERVEROUTPUT ON
BEGIN
TEST_APEX.SYS_REFCURSOR_TO_TABLE ( TEST_APEX.GET_REGION_SOURCE(
        P_IN_WORKSPACE     => '<MY WORKSPACE>',
        P_IN_APP_ID        => <APP_ID>,
        P_IN_PAGE_ID       => <PAGE_ID>,
        P_IN_REGION_NAME   => '<region name>',
        P_IN_BINDINGS_JSON => '[{"binding":"<PAGE_ITEM>","value":"<value>"}]',
        P_IN_USERNAME      => <APP_USER>
    ) );
END;
```



## 4.) run it in utPLSQL :

 ```
PROCEDURE TEST_APEX_UI AS
        VR_EXPECTED SYS_REFCURSOR;
        VR_ACTUAL   SYS_REFCURSOR;
    BEGIN
        OPEN VR_EXPECTED FOR
            SELECT
                '<expections>'      AS Expected Result
            FROM
                DUAL;

        VR_ACTUAL := TEST_APEX.GET_REGION_SOURCE(
                        P_IN_WORKSPACE     => '<MY WORKSPACE>',
                        P_IN_APP_ID        => <APP_ID>,
                        P_IN_PAGE_ID       => <PAGE_ID>,
                        P_IN_REGION_NAME   => '<regin name>',
                        P_IN_BINDINGS_JSON => '[{"binding":"<PAGE_ITEM>","value":"<value>"}]',
                        P_IN_USERNAME      => <APP_USER>
                    );

        UT.EXPECT(VR_ACTUAL).TO_(EQUAL(VR_EXPECTED)).UNORDERED;
     
    END;
```



    



