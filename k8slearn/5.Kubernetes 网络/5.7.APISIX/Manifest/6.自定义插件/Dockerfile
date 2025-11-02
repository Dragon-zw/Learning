FROM apache/apisix:2.10.0-alpine

ADD . /apisix-python-plugin-runner

RUN apk add --update python3 py3-pip && \
    cd /apisix-python-plugin-runner && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt --ignore-installed && \
    python3 setup.py install --force
