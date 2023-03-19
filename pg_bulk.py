import os
from functools import partial
from urllib import parse

import psycopg_pool
from flask import Flask

db_host = os.getenv('DB_HOST')
db_name = os.getenv('DB_NAME')
db_user = os.getenv('DB_USER')
db_pass = os.getenv('DB_PASS')

db_uri = f'postgresql://{db_user}:{parse.quote(db_pass)}@{db_host}/{db_name}'

cp = psycopg_pool.ConnectionPool(db_uri, min_size=10, max_size=50)

app = Flask(__name__)


@app.route("/ui/config")
def ui_config():
    with cp.connection() as cnx:
        one = partial(one_value, cnx)
        return one('select integrations.get_ui_config()')


@app.route("/cust/<cust_id>/intg/<intg_type>/id/<intg_id>")
def cust_intg_settings(cust_id, intg_type, intg_id):
    with cp.connection() as cnx:
        one = partial(one_value, cnx)
        return one('select integrations.get_cust_intg_settings(%s, %s, %s)',
                   (cust_id, intg_type, intg_id))


def one_value(cnx, sql, *args):
    return one_row(cnx, sql, *args)[0]


def one_row(cnx, sql, *args):
    with cnx.cursor() as cur:
        return cur.execute(sql, *args).fetchone()
