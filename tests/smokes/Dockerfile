FROM python:2.7.14-jessie

WORKDIR /workspace

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

ENTRYPOINT ["python", "-m", "unittest", "discover", "tests/smokes", "-t", "."]
