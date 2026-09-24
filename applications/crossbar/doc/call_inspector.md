### Call Inspector

#### About Call Inspector

The Call Inspector Crossbar resource allows the client to query and inspect data related to the Call Inspector application.

[More info on Call Inspector](../../call_inspector/doc/README.md).

#### Enabling the endpoint

The endpoint is registered by the `call_inspector` application itself, so it is
loaded whenever that application is running. There is nothing to enable
separately.

The endpoint queries the `call_inspector` application over AMQP, so it only
returns data while that application is running. A deployment that never starts
`call_inspector` never loads the endpoint.

Registration also adds `cb_call_inspector` to `autoload_modules` in the
`system_config/crossbar` document, so once the application has started on a
cluster the endpoint stays loaded on later Crossbar boots even if the
application is stopped. Remove it with
`sup crossbar_maintenance stop_module cb_call_inspector`.

To start the endpoint on a running node without restarting the application:

```
sup crossbar_maintenance start_module cb_call_inspector
```


#### Schema



#### Fetch

> GET /v2/accounts/{ACCOUNT_ID}/call_inspector

```shell
curl -v -X GET \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/call_inspector
```

```json
{
    "auth_token": "{AUTH_TOKEN}",
    "data": [
        {CALL_ID1},
        {CALL_ID2}
    ]
    "status": "success"
}
```

#### Read a call's SIP dialogue

> GET /v2/accounts/{ACCOUNT_ID}/call_inspector/{CALL_ID}

* `{CALL_ID}` is the unique string identifying a call. Call has to be under the authority of `{ACCOUNT_ID}`.
* `{ACCOUNT_ID}` has to be a reseller's account id.

Note: `{CHUNKS}` is an array of JSON-formatted chunks.

```shell
curl -v -X GET \
    -H "X-Auth-Token: {AUTH_TOKEN}" \
    http://{SERVER}:8000/v2/accounts/{ACCOUNT_ID}/call_inspector/{CALL_ID}
```

```json
{
    "auth_token": "{AUTH_TOKEN}",
    "data": {
        "analysis": [],
        "messages": {CHUNKS}
    }
    "request_id": "{REQUEST_ID}",
    "revision": "{REVISION}",
    "status": "success"
}
```
