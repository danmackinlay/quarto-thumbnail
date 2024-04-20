# Thumbnail images for quarto

Currently, if you use listings in Quarto, the listing page will download a full-size image from every page on the size [#9390](https://github.com/quarto-dev/quarto-cli/discussions/9390) which is slow and wasteful (most of the images are never displayed, and none of them are displayed at full size).

This extension is a workaround for that issue. It uses `libvips` to generate thumbnails of images in quarto documents, and then put the path to the thumbnail image int he page metadata.
Unfortunately, quarto does no seem to pick that image sup, so this extension is currently useless.

## Installing

This library requires [`libvips`](https://www.libvips.org/) to be in your path. See their [installation instructions](https://www.libvips.org/install.html) to install it on your local machine.

Then,
```bash
quarto add danmackinlay/quarto-thumbnail
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Using

This extension works by walking the Quarto AST of every single element and when it encounters an image, uses `libvips` to generate avif optimized images.


## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).


## Thanks

The excellent `libvips` library is used for image processing. This extension is inspired by the work of
[abhiaagarwal/optimize-images](https://github.com/abhiaagarwal/optimize-images).