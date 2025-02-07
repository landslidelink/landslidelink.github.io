/* 
  The material in this file is covered under the Espion4D License
  which should be provided along with this material
  Copyright (c) 2023 Espion4D LLC
*/
SET time zone :timezone;

Copy (
    SELECT * FROM :table
        WHERE ts > TIMESTAMPTZ :time0 AND
              ts < TIMESTAMPTZ :time1
        ORDER BY ts
    )
    to stdout DELIMITER ',' CSV HEADER;