FROM python:alpine
RUN pip install flask
WORKDIR /app
COPY part2-src/welcome-nax/welcome.py /app
EXPOSE 80
CMD python3 ./welcome.py