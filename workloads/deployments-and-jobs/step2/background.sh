#!/bin/bash

kubectl set image deployment/frontend nginx=nginx:this-tag-does-not-exist

touch /tmp/step2-applied
