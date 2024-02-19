.PHONY: pip-local-install

pip-local-install:
	@sed -i '' "s/{{VERSION_PLACEHOLDER}}/0.0.0.dev/g" setup.py && \
	pip install . --no-cache && \
	git checkout setup.py
