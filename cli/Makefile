.PHONY: pip-local-install tests coverage-report

pip-local-install:
	@sed -i '' "s/{{VERSION_PLACEHOLDER}}/0.0.0.dev/g" setup.py && \
	pip install . --no-cache && \
	git checkout setup.py


tests:
	@pytest


coverage-report:
	@coverage run -m unittest discover -s tests && \
	coverage report --omit="tests/*"
