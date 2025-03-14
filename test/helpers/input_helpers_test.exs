defmodule OpenAI.Responses.Helpers.InputHelpersTest do
  use ExUnit.Case
  alias OpenAI.Responses.Helpers.InputHelpers

  describe "create_input_message/3" do
    test "creates text-only message" do
      message = InputHelpers.create_input_message("Hello world")
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "Hello world"}
        ]
      }
    end
    
    test "creates message with URL image" do
      image_url = "https://example.com/image.jpg"
      message = InputHelpers.create_input_message("Check this image", image_url)
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "Check this image"},
          %{"type" => "input_image", "image_url" => image_url}
        ]
      }
    end
    
    test "creates message with multiple images" do
      image_urls = [
        "https://example.com/image1.jpg",
        "https://example.com/image2.jpg"
      ]
      
      message = InputHelpers.create_input_message("Compare these images", image_urls)
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "Compare these images"},
          %{"type" => "input_image", "image_url" => "https://example.com/image1.jpg"},
          %{"type" => "input_image", "image_url" => "https://example.com/image2.jpg"}
        ]
      }
    end
    
    test "supports images with detail level specified" do
      image_with_detail = {"https://example.com/image.jpg", "high"}
      message = InputHelpers.create_input_message("High detail analysis", image_with_detail)
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "High detail analysis"},
          %{"type" => "input_image", "image_url" => "https://example.com/image.jpg", "detail" => "high"}
        ]
      }
    end
    
    test "applies default detail level to all images" do
      image_urls = [
        "https://example.com/image1.jpg",
        "https://example.com/image2.jpg"
      ]
      
      message = InputHelpers.create_input_message("Compare these images", image_urls, detail: "low")
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "Compare these images"},
          %{"type" => "input_image", "image_url" => "https://example.com/image1.jpg", "detail" => "low"},
          %{"type" => "input_image", "image_url" => "https://example.com/image2.jpg", "detail" => "low"}
        ]
      }
    end
    
    test "individual detail level overrides default" do
      images = [
        "https://example.com/image1.jpg",
        {"https://example.com/image2.jpg", "high"}
      ]
      
      message = InputHelpers.create_input_message("Mixed detail analysis", images, detail: "low")
      
      assert message == %{
        "role" => "user",
        "content" => [
          %{"type" => "input_text", "text" => "Mixed detail analysis"},
          %{"type" => "input_image", "image_url" => "https://example.com/image1.jpg", "detail" => "low"},
          %{"type" => "input_image", "image_url" => "https://example.com/image2.jpg", "detail" => "high"}
        ]
      }
    end
    
    test "supports custom role" do
      message = InputHelpers.create_input_message("Hello", nil, role: "system")
      
      assert message == %{
        "role" => "system",
        "content" => [
          %{"type" => "input_text", "text" => "Hello"}
        ]
      }
    end
  end
end