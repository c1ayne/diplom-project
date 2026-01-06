#!/bin/bash

echo "DESTROYING EVERYTHING in iot-system namespace..."

kubectl delete namespace iot-system

echo "All gone."