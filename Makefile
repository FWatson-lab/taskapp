.PHONY: install init seed run test clean docker

install:
	pip install -r requirements.txt

init:
	bash scripts/init_db.sh

seed:
	python3 scripts/seed.py

run:
	python3 -m backend.app

test:
	PYTHONPATH=. pytest tests/ -v

clean:
	rm -f tasks.db
	find . -type d -name __pycache__ -exec rm -rf {} +

docker:
	docker build -t taskapp .
	docker run -p 5000:5000 taskapp
