
docker build --tag nginx-test:peach .

docker network create inception-test-net

docker network ls

docker run -d --name wordpress --network inception-test-net alpine:3.21 sleep infinity

docker ps -a


docker run -d --name nginx-peach -p 443:443 --network inception-test-net nginx-test:peach 

docker ps -a

curl --insecure --verbose https://127.0.0.1:443/

*   Trying 127.0.0.1:443...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use http/1.1
* Server certificate:
*  subject: C=JP; ST=Tokyo; L=Shinjukuku; O=42Tokyo; OU=42cursus; CN=tvaroux
*  start date: Jun 23 16:09:17 2026 GMT
*  expire date: Jun 23 16:09:17 2027 GMT
*  issuer: C=JP; ST=Tokyo; L=Shinjukuku; O=42Tokyo; OU=42cursus; CN=tvaroux
*  SSL certificate verify result: self-signed certificate (18), continuing anyway.
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.81.0
> Accept: */*
> 
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Mark bundle as not supporting multiuse
< HTTP/1.1 502 Bad Gateway
< Server: nginx/1.28.3
< Date: Tue, 23 Jun 2026 16:31:00 GMT
< Content-Type: text/html
< Content-Length: 157
< Connection: keep-alive
< 
<html>
<head><title>502 Bad Gateway</title></head>
<body>



curl --insecure  https://127.0.0.1:443/curl --insecure --verbose http://127.0.0.1:443/
*   Trying 127.0.0.1:443...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS header, Finished (20):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.2 (OUT), TLS header, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use http/1.1
* Server certificate:
*  subject: C=JP; ST=Tokyo; L=Shinjukuku; O=42Tokyo; OU=42cursus; CN=tvaroux
*  start date: Jun 23 16:09:17 2026 GMT
*  expire date: Jun 23 16:09:17 2027 GMT
*  issuer: C=JP; ST=Tokyo; L=Shinjukuku; O=42Tokyo; OU=42cursus; CN=tvaroux
*  SSL certificate verify result: self-signed certificate (18), continuing anyway.
* TLSv1.2 (OUT), TLS header, Supplemental data (23):
> GET /curl HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.81.0
> Accept: */*
> 
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* TLSv1.2 (IN), TLS header, Supplemental data (23):
* Mark bundle as not supporting multiuse
< HTTP/1.1 502 Bad Gateway
< Server: nginx/1.28.3
< Date: Tue, 23 Jun 2026 16:48:42 GMT
< Content-Type: text/html
< Content-Length: 157
< Connection: keep-alive
< 
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.28.3</center>
</body>
</html>
* Connection #0 to host 127.0.0.1 left intact
* Found bundle for host 127.0.0.1: 0x650caf0ea1e0 [serially]
* Can not multiplex, even if we wanted to!
* Hostname 127.0.0.1 was found in DNS cache
*   Trying 127.0.0.1:443...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#1)
> GET / HTTP/1.1
> Host: 127.0.0.1:443
> User-Agent: curl/7.81.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 400 Bad Request
< Server: nginx/1.28.3
< Date: Tue, 23 Jun 2026 16:48:42 GMT
< Content-Type: text/html
< Content-Length: 255
< Connection: close
< 
<html>
<head><title>400 The plain HTTP request was sent to HTTPS port</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<center>The plain HTTP request was sent to HTTPS port</center>
<hr><center>nginx/1.28.3</center>
</body>
</html>
* Closing connection 1
