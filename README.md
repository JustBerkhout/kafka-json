

```
kafka-topics.sh --bootstrap-server gkm:9092 --create --topic movie
```


## The Schema
Read https://json-schema.org/

Movie schema:
- movie-id, integer (required)
- title, string (required)
- year, integer
- tags, array of 1 or more strings

see [movie-schema.json]


## Register schema in Schema Registry

Use `jq` to reform the payload schema (movie-schema.json) into the wrapper that Confluent Schemaregistry requires
See: https://stackoverflow.com/questions/61890455/create-a-new-entry-in-kafka-schema-registry-using-a-file-curl
and: https://rmoff.net/2019/01/17/confluent-schema-registry-rest-api-cheatsheet/

Ensure to add the `schemaType:"JSON"` attribute to override the default

https://docs.confluent.io/platform/current/schema-registry/develop/api.html#post--subjects-(string-%20subject)-versions

```
jq '. | {schema: tojson, schemaType:"JSON"}' movie-schema.json | \
curl -X POST http://gkm:8081/subjects/movie-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @-
```

## Little side note
For some reason the `kafka-json-schema-console-...` tools are started by the `schema-registry-run-class` script instead of the `kafka-run-class`. This means it calls a different default file for `log4j` properties (`schema-registry/log4j.properties`) instead of the normal `tools-log4j.properties`. This causes a little more verbose logging. I've copied a `tools-log4j.properties` into this repo and actually change the logging level to `FATAL` to get rid of the logs on stderr that aren't necessary or helpful for this demo. 

to do this set an ENV variable to reference the log4j properties you want, before running the `kafka-json-schema-console-...` tools.

```
export SCHEMA_REGISTRY_LOG4J_OPTS="-Dlog4j.configuration=file:tools-log4j.properties"
```


## Produce some movies in JSON
```
kafka-json-schema-console-producer --bootstrap-server gkm:9092 --topic movie \
--property value.schema.file=movie-schema.json \
--property schema.registry.url=http://gkm:8081 < movies.file
```

## consume using JSON Consumer

```
kafka-json-schema-console-consumer --bootstrap-server gkm:9092 --topic movie \
--property schema.registry.url=http://gkm:8081 \
--from-beginning 

```

## consume using plain consumer
```
$ kafka-console-consumer --bootstrap-server gkm:9092 --topic movie --from-beginning
```



## Connect datagen

Relies on `JsonSchemaConverter`
Appears already installed on `confluentinc/cp-kafka-connect:7.6.1`

```
 curl -i -X PUT http://gkm:8083/connectors/datagen_local_01/config \
     -H "Content-Type: application/json" \
     -d '{
            "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
            "key.converter": "org.apache.kafka.connect.storage.StringConverter",
            "value.converter": "io.confluent.connect.json.JsonSchemaConverter",
            "value.converter.schema.registry.url": "http://schema-registry:8081",          
            "kafka.topic": "pageviews",
            "quickstart": "pageviews",
            "max.interval": 1000,
            "iterations": 10000000,
            "tasks.max": "1"
        }' | jq
```

NOTE the `value-converter` runs in the connect task runtime, and appears to only have access to the 
docker hostnames (i.e. must be `http://schema-registry:8081"`)


```
kafka-console-consumer --bootstrap-server gkm:9092 --topic pageviews | jq
```

```
kafka-json-schema-console-consumer --bootstrap-server gkm:9092 --topic pageviews --property schema.registry.url=http://gkm:8081 | jq
```


## postgres source

### datagen script

source `psql` env variables.
```
. pg.env
```

run script

```
./pg-insert-script.sh
```

### source connector

Relies on `JsonSchemaConverter`
Appears already installed on `confluentinc/cp-kafka-connect:7.6.1`

```
 curl -i -X PUT http://gkm:8083/connectors/pg-instrument-reading-source/config \
     -H "Content-Type: application/json" \
     -d '@pg-source-config.json' | jq
```

```
kafka-console-consumer --bootstrap-server gkm:9092 --topic pageviews | jq
```