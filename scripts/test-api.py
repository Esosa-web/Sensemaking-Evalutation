import os
from google import genai

client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents="Say hello in exactly 5 words."
)
print(response.text)
print("API connection working.")
