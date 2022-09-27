FROM python:alpine
RUN pip install flask
WORKDIR /app
COPY part1-src/hello-world/hello.py /app
EXPOSE 80
CMD python3 ./hello.py