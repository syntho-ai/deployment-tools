.PHONY: tests coverage-report

tests:
	@pytest

coverage-report:
	@coverage run -m unittest discover -s tests && \
	coverage report --omit="tests/*"
