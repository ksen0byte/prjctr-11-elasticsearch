# Start from a base image with curl and jq installed
FROM alpine:latest

# Install curl and jq
RUN apk add --no-cache curl jq bash

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the script and any other necessary files into the container
COPY import_and_search.sh .
COPY english-words.txt .

# Make the script executable
RUN chmod +x import_and_search.sh

# Command to run on container start
CMD [ "./import_and_search.sh" ]
