import tensorflow as tf
import numpy as np
import json
from networkModel import NetworkModel


class FederatedModel():
    def __init__(self, network_model: NetworkModel):
        super().__init__()
        self.model: NetworkModel = network_model

    def serialize(self) -> str:
        config = self.model.get_config()
        weights = [w.tolist() for w in self.model.get_weights()]
        return json.dumps({"config": config, "weights": weights})

    def update_weights(self, node_output: list[list, int]):
        new_weights = FederatedModel.federated_weight_average(node_output)
        self.model.set_weights(new_weights)

    @staticmethod
    def federated_weight_average(node_outputs: list[list, int]) -> np.array:
        # node_output[i][0] -> weights, node_output[i][1] -> data_size
        ds_size = sum(output[1] for output in node_outputs)

        # Initialize the weighted sum with zeros, using the shape of the first client's weights
        new_weights = np.zeros_like(node_outputs[0][0])
        
        for weights, size in node_outputs:
            new_weights += weights * (size / ds_size)
        
        return new_weights
