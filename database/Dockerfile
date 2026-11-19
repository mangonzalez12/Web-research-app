FROM python:3.12-slim

WORKDIR /migrate
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

CMD ["sh", "-c", "python db.py && python seed_food_items.py && python setup_roles.py"]