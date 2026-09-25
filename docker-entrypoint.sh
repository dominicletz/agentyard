#!/bin/sh

set -eu

/app/bin/agentyard eval "AgentYard.Release.migrate()"
exec /app/bin/agentyard start
