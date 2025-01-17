from tensorflow.keras.utils import to_categorical
import numpy as np

start_train: int = 0
start_test: int = 0
len_train: int = 12000
len_test: int = 2000

list_data_path = [
    "./priv/Dataset/train-images-idx3-ubyte/train-images-idx3-ubyte",
    "./priv/Dataset/train-labels-idx1-ubyte/train-labels-idx1-ubyte",
    "./priv/Dataset/t10k-images-idx3-ubyte/t10k-images-idx3-ubyte",
    "./priv/Dataset/t10k-labels-idx1-ubyte/t10k-labels-idx1-ubyte"
]


# load data and split it to train, test
def load_images_and_labels(file_path, image=False, label=False):
    if image:
        with open(file_path, "rb") as file:    
            file.read(16)    # Skip the header for images
            binary_data = file.read()
        numpy_data = np.frombuffer(binary_data, dtype=np.uint8)
        num_images = numpy_data.size // 784 
        data = numpy_data.reshape(num_images, 784)
        return (data)
    
    if label:
        with open(file_path, "rb") as file:
            file.read(8)    # Skip the header for labels
            binary_data = file.read()
        numpy_data = np.frombuffer(binary_data, dtype=np.uint8)
        return (numpy_data)


def get_dataset():
    # Split the Data
    x_train = load_images_and_labels(list_data_path[0], image=True, label=False)[start_train:start_train+len_train]
    y_train = load_images_and_labels(list_data_path[1], image=False, label=True)[start_train:start_train+len_train]
    x_test = load_images_and_labels(list_data_path[2], image=True, label=False)[start_test:start_test+len_test]
    y_test = load_images_and_labels(list_data_path[3], image=False, label=True)[start_test:start_test+len_test]

    # Resizing the Data
    x_train = x_train.reshape(x_train.shape[0], 28,28)
    x_test = x_test.reshape(x_test.shape[0], 28,28)

    # Normalize the Data
    x_train = x_train / 255.0
    x_test = x_test / 255.0

    # Labelling Data,
    y_train = to_categorical(y_train, 10)
    y_test = to_categorical(y_test, 10)

    return x_train, y_train, x_test, y_test
