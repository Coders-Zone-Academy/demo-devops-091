import os
import re
import requests
import pandas as pd
import s3fs

def run_x_etl():
    fs = s3fs.S3FileSystem(
    anon=False,
    client_kwargs={
        "region_name": "us-east-2"
    })

    API_KEY = os.getenv("TWITTERAPI_IO_API_KEY")

    BASE_URL = "https://api.twitterapi.io/twitter/user/last_tweets"

    USERNAME = "NASA"
    TOTAL_TWEETS = 20

    headers = {
        "X-API-Key": API_KEY
    }

    tweets = []
    cursor = ""

    while len(tweets) < TOTAL_TWEETS:

        params = {
            "userName": USERNAME
        }

        # Enviar el cursor para recuperar la siguiente página
        if cursor:
            params["cursor"] = cursor

        response = requests.get(
            BASE_URL,
            headers=headers,
            params=params,
            timeout=30
        )

        response.raise_for_status()

        result = response.json()

        if result.get("status") == "error":
            raise Exception(result.get("msg", "Error en TwitterAPI.io"))

        # Extraer los tweets de la respuesta
        page_tweets = result.get("data", {}).get("tweets", [])

        if not page_tweets:
            break

        tweets.extend(page_tweets)

        print(f"Tweets obtenidos: {len(tweets)}")

        # Obtener el cursor de la siguiente página
        cursor = result.get("next_cursor")

        # Comprobar si existen más páginas
        if not result.get("has_next_page"):
            break

    # Conservar exactamente los últimos 200 obtenidos
    tweets = tweets[:TOTAL_TWEETS]

    print(f"Total de tweets recuperados: {len(tweets)}")

    tweet_list = []
    # Mostrar los tweets
    for tweet in tweets:
        # Obtener el diccionario author
        author = tweet.get("author", {})

        text_without_spaces = " ".join((tweet.get("text") or "").split())
        clean_text = re.sub(r"\s*\S*[.…]{1,}\s*$", "", text_without_spaces)

        refined_tweet = {
            'ID': tweet.get("id"),
            'User': author.get("userName"),
            'Texto': clean_text,
            'Likes': tweet.get("likeCount"),
            'Views': tweet.get("viewCount"),
            'Retweets': tweet.get("retweetCount"),
            'Replies': tweet.get("replyCount"),
            'Fecha': tweet.get("createdAt")
        }

        tweet_list.append(refined_tweet)

    df = pd.DataFrame(tweet_list)
    df.to_csv("s3://my-website-sqd-6571/nasa_x_data.csv")