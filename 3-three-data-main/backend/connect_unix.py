# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START cloud_sql_mysql_sqlalchemy_connect_unix]
import os

import sqlalchemy


def connect_unix_socket() -> sqlalchemy.engine.base.Engine:
    """Initializes a Unix socket connection pool for a Cloud SQL instance of MySQL.

    Enhancement: If only `INSTANCE_CONNECTION_NAME` is provided (and
    `INSTANCE_UNIX_SOCKET` is absent), we derive the Unix socket path as
    `/cloudsql/<INSTANCE_CONNECTION_NAME>` so you can rely solely on
    `INSTANCE_CONNECTION_NAME` with the *Unix socket* auth style (DB_USER/DB_PASS).
    This allows choosing between traditional user/password vs IAM (connector)
    simply by which credential env vars you export (`DB_USER`/`DB_PASS` vs `DB_IAM_USER`).
    """
    # Note: Saving credentials in environment variables is convenient, but not
    # secure - consider a more secure solution such as Cloud Secret Manager.
    db_user = os.environ["DB_USER"]  # e.g. 'my-database-user'
    db_pass = os.environ["DB_PASS"]  # e.g. 'my-database-password'
    db_name = os.environ["DB_NAME"]  # e.g. 'my-database'

    # Prefer explicit INSTANCE_UNIX_SOCKET if set; otherwise derive from INSTANCE_CONNECTION_NAME
    unix_socket_path = os.environ.get("INSTANCE_UNIX_SOCKET")
    if not unix_socket_path:
        instance_connection_name = os.environ.get("INSTANCE_CONNECTION_NAME")
        if not instance_connection_name:
            raise KeyError(
                "Either INSTANCE_UNIX_SOCKET or INSTANCE_CONNECTION_NAME must be set to use the unix socket connection." \
            )
        unix_socket_path = f"/cloudsql/{instance_connection_name}"  # default Cloud Run/App Engine mount path

    pool = sqlalchemy.create_engine(
        sqlalchemy.engine.url.URL.create(
            drivername="mysql+pymysql",
            username=db_user,
            password=db_pass,
            database=db_name,
            query={"unix_socket": unix_socket_path},
        ),
        # [START_EXCLUDE]
        pool_size=5,
        max_overflow=2,
        pool_timeout=30,  # 30 seconds
        pool_recycle=1800,  # 30 minutes
        # [END_EXCLUDE]
    )
    return pool


# [END cloud_sql_mysql_sqlalchemy_connect_unix]
