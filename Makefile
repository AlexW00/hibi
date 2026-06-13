APPLE_TEAM_ID ?= $(shell defaults read /dev/null 2>/dev/null; echo YOURTEAMID)
CONTAINER_ID := iCloud.com.weichart.hibi

ck-export:
	xcrun cktool export-schema --team-id "$(APPLE_TEAM_ID)" --container-id "$(CONTAINER_ID)" --environment development --output-file CloudKit/schema.ckdb

ck-check:
	xcrun cktool export-schema --team-id "$(APPLE_TEAM_ID)" --container-id "$(CONTAINER_ID)" --environment production --output-file /tmp/production.ckdb
	@diff -u CloudKit/schema.ckdb /tmp/production.ckdb && echo "✅ Production matches committed schema" || (echo "❌ Deploy schema in CloudKit Console, then rerun"; exit 1)
