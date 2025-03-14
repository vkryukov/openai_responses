defmodule OpenAI.Responses.Helpers.ImageHelpers do
  @moduledoc """
  Helper functions for creating structured messages with images for the OpenAI Responses API.
  """

  @supported_image_extensions [".png", ".jpeg", ".jpg", ".webp", ".gif"]
  @image_mime_types %{
    ".png" => "image/png",
    ".jpeg" => "image/jpeg",
    ".jpg" => "image/jpeg",
    ".webp" => "image/webp",
    ".gif" => "image/gif"
  }

  @doc """
  Creates a structured message with text and images for vision-based models.

  ## Parameters

    * `text` - The text prompt to include in the message
    * `images` - Optional image(s) to include, can be:
      * A single image (URL string, file path, or {url/path, detail} tuple)
      * A list of images (URL strings, file paths, or {url/path, detail} tuples)
    * `opts` - Options for the message:
      * `:detail` - Default detail level for all images: "low", "high", or "auto" (default)
      * `:role` - Message role, defaults to "user"

  ## Image Specification

  Images can be specified in several ways:
    * URL string: "https://example.com/image.jpg"
    * Local file path: "/path/to/image.jpg"
    * Tuple with detail level: {"https://example.com/image.jpg", "high"}
    * Tuple with detail level: {"/path/to/image.jpg", "low"}

  Local image files will be automatically encoded as Base64 data URLs.
  Supported image formats: #{Enum.join(@supported_image_extensions, ", ")}

  ## Examples

      # Simple text with one image URL
      iex> create_message_with_images("What is in this image?", "https://example.com/image.jpg")

      # Text with a local image file
      iex> create_message_with_images("Describe this image", "/path/to/image.jpg")

      # Using high detail for all images
      iex> create_message_with_images("Analyze in detail", ["img1.jpg", "img2.jpg"], detail: "high")

      # Mixed image sources with specific detail levels
      iex> create_message_with_images(
      ...>   "Compare these", 
      ...>   [
      ...>     {"img1.jpg", "low"},
      ...>     {"https://example.com/img2.jpg", "high"}
      ...>   ]
      ...> )

      # Text-only message
      iex> create_message_with_images("Just a text question")
  """
  @spec create_message_with_images(String.t(), String.t() | {String.t(), String.t()} | [String.t() | {String.t(), String.t()}] | nil, keyword()) :: map()
  def create_message_with_images(text, images \\ nil, opts \\ []) do
    default_detail = Keyword.get(opts, :detail)
    role = Keyword.get(opts, :role, "user")
    
    content = [%{"type" => "input_text", "text" => text}]
    
    content = case images do
      nil -> 
        content
      images when is_list(images) -> 
        content ++ Enum.map(images, &process_image(&1, default_detail))
      image -> 
        content ++ [process_image(image, default_detail)]
    end
    
    %{
      "role" => role,
      "content" => content
    }
  end
  
  # Process a single image (URL, file path, or tuple with detail)
  defp process_image({image_src, detail}, _default_detail) do
    create_image_content(image_src, detail)
  end
  
  defp process_image(image_src, default_detail) do
    create_image_content(image_src, default_detail)
  end
  
  # Create image content based on source type (URL or file)
  defp create_image_content(image_src, detail) do
    image_content = %{
      "type" => "input_image",
      "image_url" => process_image_source(image_src)
    }
    
    if detail do
      Map.put(image_content, "detail", detail)
    else
      image_content
    end
  end
  
  # Process image source - either URL or file path
  defp process_image_source(image_src) do
    cond do
      String.starts_with?(image_src, ["http://", "https://", "data:"]) ->
        # Already a URL or data URL, use as-is
        image_src
      File.exists?(image_src) ->
        # Local file, encode to Base64
        encode_image_file(image_src)
      true ->
        # Not a recognized format
        raise ArgumentError, "Image source '#{image_src}' is not a valid URL or existing file"
    end
  end
  
  # Encode a local image file to Base64 data URL
  defp encode_image_file(file_path) do
    ext = Path.extname(file_path)
    
    unless ext in @supported_image_extensions do
      raise ArgumentError, "Unsupported image format: #{ext}. Supported formats: #{Enum.join(@supported_image_extensions, ", ")}"
    end
    
    mime_type = Map.fetch!(@image_mime_types, ext)
    
    case File.read(file_path) do
      {:ok, binary} ->
        base64 = Base.encode64(binary)
        "data:#{mime_type};base64,#{base64}"
      {:error, reason} ->
        raise "Failed to read image file '#{file_path}': #{reason}"
    end
  end
end