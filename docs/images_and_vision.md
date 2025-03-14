# Images and vision

Learn how to use vision capabilities to understand images.

**Vision** is the ability to use images as input prompts to a model, and
generate responses based on the data inside those images. Find out which models
are capable of vision [on the models page](/docs/models). To generate images as
_output_, see our
[specialized model for image generation](/docs/guides/image-generation).

You can provide images as input to generation requests either by providing a
fully qualified URL to an image file, or providing an image as a Base64-encoded
data URL.

Passing a URL

Analyze the content of an image

```javascript
import OpenAI from "openai";

const openai = new OpenAI();

const response = await openai.responses.create({
  model: "gpt-4o-mini",
  input: [
    {
      role: "user",
      content: [
        { type: "input_text", text: "what's in this image?" },
        {
          type: "input_image",
          image_url:
            "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
        },
      ],
    },
  ],
});

console.log(response.output_text);
```

```python
from openai import OpenAI

client = OpenAI()

response = client.responses.create(
    model="gpt-4o-mini",
    input=[{
        "role": "user",
        "content": [
            {"type": "input_text", "text": "what's in this image?"},
            {
                "type": "input_image",
                "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
            },
        ],
    }],
)

print(response.output_text)
```

```bash
curl https://api.openai.com/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o-mini",
    "input": [
      {
        "role": "user",
        "content": [
          {"type": "input_text", "text": "what is in this image?"},
          {
            "type": "input_image",
            "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"
          }
        ]
      }
    ]
  }'
```

Passing a Base64 encoded image

Analyze the content of an image

```javascript
import fs from "fs";
import OpenAI from "openai";

const openai = new OpenAI();

const imagePath = "path_to_your_image.jpg";
const base64Image = fs.readFileSync(imagePath, "base64");

const response = await openai.responses.create({
  model: "gpt-4o-mini",
  input: [
    {
      role: "user",
      content: [
        { type: "input_text", text: "what's in this image?" },
        {
          type: "input_image",
          image_url: `data:image/jpeg;base64,${base64Image}`,
        },
      ],
    },
  ],
});

console.log(response.output_text);
```

```python
import base64
from openai import OpenAI

client = OpenAI()

# Function to encode the image
def encode_image(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")

# Path to your image
image_path = "path_to_your_image.jpg"

# Getting the Base64 string
base64_image = encode_image(image_path)

response = client.responses.create(
    model="gpt-4o",
    input=[
        {
            "role": "user",
            "content": [
                { "type": "input_text", "text": "what's in this image?" },
                {
                    "type": "input_image",
                    "image_url": f"data:image/jpeg;base64,{base64_image}",
                },
            ],
        }
    ],
)

print(response.output_text)
```

## Image input requirements

Input images must meet the following requirements to be used in the API.

|| |PNG (.png)JPEG (.jpeg and .jpg)WEBP (.webp)Non-animated GIF (.gif)|Up to
20MB per imageLow-resolution: 512px x 512pxHigh-resolution: 768px (short side) x
2000px (long side)|No watermarks or logosNo textNo NSFW contentClear enough for
a human to understand|

## Specify image input detail level

The `detail` parameter tells the model what level of detail to use when
processing and understanding the image (`low`, `high`, or `auto` to let the
model decide). If you skip the parameter, the model will use `auto`. Put it
right after your `image_url`, like this:

```plain
{
    "type": "input_image",
    "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
    "detail": "high",
}
```

You can save tokens and speed up responses by using `"detail": "low"`. This lets
the model process the image with a budget of 85 tokens. The model receives a
low-resolution 512px x 512px version of the image. This is fine if your use case
doesn't require the model to see with high-resolution detail (for example, if
you're asking about the dominant shape or color in the image).

Or give the model more detail to generate its understanding by using
`"detail": "high"`. This lets the model see the low-resolution image (using 85
tokens) and then creates detailed crops using 170 tokens for each 512px x 512px
tile.

Note that the above token budgets for image processing do not currently apply to
the GPT-4o mini model, but the image processing cost is comparable to GPT-4o.
For the most precise and up-to-date estimates for image processing, please use
the image pricing calculator [here](https://openai.com/api/pricing/)

## Provide multiple image inputs

The [Responses API](https://platform.openai.com/docs/api-reference/responses)
can take in and process multiple image inputs. The model processes each image
and uses information from all images to answer the question.

Multiple image inputs

```javascript
import OpenAI from "openai";

const openai = new OpenAI();

const response = await openai.responses.create({
  model: "gpt-4o-mini",
  input: [
    {
      role: "user",
      content: [
        {
          type: "input_text",
          text: "What are in these images? Is there any difference between them?",
        },
        {
          type: "input_image",
          image_url:
            "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
        },
        {
          type: "input_image",
          image_url:
            "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
        },
      ],
    },
  ],
});

console.log(response.output_text);
```

```python
from openai import OpenAI

client = OpenAI()

response = client.responses.create(
    model="gpt-4o-mini",
    input=[
        {
            "role": "user",
            "content": [
                {
                    "type": "input_text",
                    "text": "What are in these images? Is there any difference between them?",
                },
                {
                    "type": "input_image",
                    "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
                },
                {
                    "type": "input_image",
                    "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
                },
            ],
        }
    ]
)

print(response.output_text)
```

```bash
curl https://api.openai.com/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o-mini",
    "input": [
      {
        "role": "user",
        "content": [
          {
            "type": "input_text",
            "text": "What are in these images? Is there any difference between them?"
          },
          {
            "type": "input_image",
            "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"
          },
          {
            "type": "input_image",
            "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"
          }
        ]
      }
    ]
  }'
```

Here, the model is shown two copies of the same image. It can answer questions
about both images or each image independently.

## Limitations

While models with vision capabilities are powerful and can be used in many
situations, it's important to understand the limitations of these models. Here
are some known limitations:

- **Medical images**: The model is not suitable for interpreting specialized
  medical images like CT scans and shouldn't be used for medical advice.
- **Non-English**: The model may not perform optimally when handling images with
  text of non-Latin alphabets, such as Japanese or Korean.
- **Small text**: Enlarge text within the image to improve readability, but
  avoid cropping important details.
- **Rotation**: The model may misinterpret rotated or upside-down text and
  images.
- **Visual elements**: The model may struggle to understand graphs or text where
  colors or styles—like solid, dashed, or dotted lines—vary.
- **Spatial reasoning**: The model struggles with tasks requiring precise
  spatial localization, such as identifying chess positions.
- **Accuracy**: The model may generate incorrect descriptions or captions in
  certain scenarios.
- **Image shape**: The model struggles with panoramic and fisheye images.
- **Metadata and resizing**: The model doesn't process original file names or
  metadata, and images are resized before analysis, affecting their original
  dimensions.
- **Counting**: The model may give approximate counts for objects in images.
- **CAPTCHAS**: For safety reasons, our system blocks the submission of
  CAPTCHAs.

## Calculating costs

Image inputs are metered and charged in tokens, just as text inputs are. The
token cost of an image is determined by two factors: size and detail.

Any image with `"detail": "low"` costs 85 tokens. To calculate the cost of an
image with `"detail": "high"`, we do the following:

- Scale to fit in a 2048px x 2048px square, maintaining original aspect ratio
- Scale so that the image's shortest side is 768px long
- Count the number of 512px squares in the image—each square costs **170
  tokens**
- Add **85 tokens** to the total

### Cost calculation examples

- A 1024 x 1024 square image in `"detail": "high"` mode costs 765 tokens
  - 1024 is less than 2048, so there is no initial resize.
  - The shortest side is 1024, so we scale the image down to 768 x 768.
  - 4 512px square tiles are needed to represent the image, so the final token
    cost is `170 * 4 + 85 = 765`.
- A 2048 x 4096 image in `"detail": "high"` mode costs 1105 tokens
  - We scale down the image to 1024 x 2048 to fit within the 2048 square.
  - The shortest side is 1024, so we further scale down to 768 x 1536.
  - 6 512px tiles are needed, so the final token cost is `170 * 6 + 85 = 1105`.
- A 4096 x 8192 image in `"detail": "low"` most costs 85 tokens
  - Regardless of input size, low detail images are a fixed cost.

We process images at the token level, so each image we process counts towards
your tokens per minute (TPM) limit. See the calculating costs section for
details on the formula used to determine token count per image.
