local:
	bundle exec jekyll build -d _site -s src --config _config.yml,_config-local.yml

serve-local:
	bundle exec jekyll serve -d _site -s src --config _config.yml,_config-local.yml

# make approve SUMMARY="mnogo dobro" TOKEN="2ea26cc6-1e20-4cef-84f4-8f0c62b6952e"
approve:
	aws codepipeline put-approval-result --pipeline-name serverless-pub-site --stage-name deploy-to-test --action-name approve --result "summary=$(SUMMARY),status=Approved" --token $(TOKEN)

reject:
	aws codepipeline put-approval-result --pipeline-name serverless-pub-site --stage-name deploy-to-test --action-name approve --result "summary=$(SUMMARY),status=Rejected" --token $(TOKEN)
