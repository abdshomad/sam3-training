# SAM3 Training Repository

This repository is dedicated to training and fine-tuning the Meta Segment Anything Model 3 (SAM 3).

## Overview

SAM 3 is a powerful segmentation model that can segment objects in images and videos based on text prompts, geometry, and image exemplars. This repository contains the SAM 3 codebase as a submodule and provides a dedicated workspace for training and fine-tuning tasks.

## Repository Structure

- `sam3/` - SAM 3 codebase (git submodule from [facebookresearch/sam3](https://github.com/facebookresearch/sam3))

## Getting Started

### Prerequisites

- Python 3.8+
- CUDA-capable GPU (recommended)
- Git with submodule support

### Setup

1. Clone this repository:
   ```bash
   git clone --recurse-submodules <your-repo-url>
   ```

   Or if you've already cloned without submodules:
   ```bash
   git submodule update --init --recursive
   ```

2. Install dependencies:
   ```bash
   cd sam3
   pip install -e ".[dev,train]"
   ```

### Training

Refer to the [SAM 3 training documentation](sam3/README_TRAIN.md) for detailed instructions on how to train and fine-tune the model.

## Resources

- [SAM 3 Official Website](https://ai.meta.com/sam3/)
- [SAM 3 Paper](https://arxiv.org/abs/2511.16719)
- [Original SAM 3 Repository](https://github.com/facebookresearch/sam3)

## License

This repository follows the SAM License. See the [LICENSE](sam3/LICENSE) file in the submodule for details.