#!/bin/bash

# Define variables
ES_HOST="${ES_HOST:-localhost:9200}"
INDEX_NAME="autocomplete_index"
WORDS_FILE="english-words.txt"
BULK_FILE="bulk_data.json"
SEARCH_TERM="qxamqplq"  # "example" with 3 typos

# Function to check if Elasticsearch is running
check_es() {
    while true; do
        if curl -sS "$ES_HOST" >/dev/null; then
            echo "Elasticsearch is up!"
            break
        else
            echo "Waiting for Elasticsearch to start..."
            sleep 5
        fi
    done
}

# Convert words file to Elasticsearch bulk format
echo "Converting $WORDS_FILE to Elasticsearch bulk format..."
> "$BULK_FILE"
while IFS= read -r line; do
    echo '{"index":{"_index":"'"$INDEX_NAME"'"}}' >> "$BULK_FILE"
    echo '{"word":"'"$line"'"}' >> "$BULK_FILE"
done < "$WORDS_FILE"

# Wait for Elasticsearch to start
check_es

# Create the index with bigram and trigram filters
echo "Creating index with settings..."
curl -sS -X PUT "$ES_HOST/$INDEX_NAME" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "analysis": {
      "filter": {
        "bigram_filter": {
          "type": "ngram",
          "min_gram": 2,
          "max_gram": 2
        },
        "trigram_filter": {
          "type": "ngram",
          "min_gram": 3,
          "max_gram": 3
        }
      },
      "analyzer": {
        "bigram": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "bigram_filter"]
        },
        "trigram": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "trigram_filter"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "word": {
        "type": "text",
        "fields": {
          "bigram": {
            "type": "text",
            "analyzer": "bigram"
          },
          "trigram": {
            "type": "text",
            "analyzer": "trigram"
          }
        }
      }
    }
  }
}
' > index_create_log.txt

# Add data into index
echo "Indexing data..."
curl -sS -X POST "$ES_HOST/_bulk" -H 'Content-Type: application/json' --data-binary @"$BULK_FILE" > bulk_indexing_log.txt

# Search for the word with typos
echo "Searching for the word [$SEARCH_TERM] with typos..."
curl -sS -X GET "$ES_HOST/$INDEX_NAME/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "word.bigram": "'"$SEARCH_TERM"'"
          }
        },
        {
          "match": {
            "word.trigram": "'"$SEARCH_TERM"'"
          }
        },
        {
          "match": {
            "word": {
              "query": "'"$SEARCH_TERM"'",
              "fuzziness": "AUTO"
            }
          }
        }
      ]
    }
  }
}
' | jq '.hits.hits[]._source.word'
