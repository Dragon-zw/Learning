```sh
➜ kubectl get pod -n apisix -l app.kubernetes.io/name=apisix
NAME                      READY   STATUS    RESTARTS   AGE
apisix-5c9979777f-tq6mm   1/1     Running   0          3d5h

➜ kubectl exec -it -n apisix $(kubectl get pod -n apisix -l app.kubernetes.io/name=apisix -oname | awk -F'/' '{print $2}') -- /bin/sh
Defaulted container "apisix" out of: apisix, wait-etcd (init)
/usr/local/apisix # curl http://127.0.0.1:9180/apisix/admin/consumers -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
> {
>     "username": "jack1",
>     "plugins": {
>         "basic-auth": {
>             "username":"jack2019",
>             "password": "123456"
>         }
>     }
> }'
HTTP/1.1 200 OK
Date: Sun, 02 Nov 2025 07:34:29 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.10.0
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Expose-Headers: *
Access-Control-Max-Age: 3600

{"action":"set","node":{"key":"\/apisix\/consumers\/jack1","value":{"plugins":{"basic-auth":{"password":"123456","username":"jack2019"}},"create_time":1762068699,"username":"jack1","update_time":1762068869}}}

/usr/local/apisix # curl http://127.0.0.1:9180/apisix/admin/consumers -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
> {
>     "username": "jack2",
>     "plugins": {
>         "basic-auth": {
>             "username":"jack2020",
>             "password": "123456"
>         }
>     }
> }'
HTTP/1.1 201 Created
Date: Sun, 02 Nov 2025 07:35:20 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.10.0
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Expose-Headers: *
Access-Control-Max-Age: 3600

{"action":"set","node":{"key":"\/apisix\/consumers\/jack2","value":{"plugins":{"basic-auth":{"password":"123456","username":"jack2020"}},"create_time":1762068920,"username":"jack2","update_time":1762068920}}}

/usr/local/apisix # curl http://127.0.0.1:9180/apisix/admin/routes/1 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
> {
>     "uri": "/index.html",
>     "upstream": {
>         "type": "roundrobin",
>         "nodes": {
>             "127.0.0.1:1980": 1
>         }
>     },
>     "plugins": {
>         "basic-auth": {},
>         "consumer-restriction": {
>             "whitelist": [
>                 "jack1"
>             ]
>         }
>     }
> }'
{"action":"set","node":{"key":"\/apisix\/routes\/1","value":{"update_time":1762068967,"upstream":{"pass_host":"pass","nodes":{"127.0.0.1:1980":1},"type":"roundrobin","scheme":"http","hash_on":"vars"},"id":"1","status":1,"plugins":{"basic-auth":{},"consumer-restriction":{"rejected_code":403,"whitelist":["jack1"],"type":"consumer_name"}},"priority":0,"create_time":1762068967,"uri":"\/index.html"}}}
```