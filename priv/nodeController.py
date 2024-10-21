import tensorflow as tf
import json
from networkModel import NetworkModel


class NodeController:

    def __init__(self):
        self.master_pid: int
        self.node_id: int
        self.model: NetworkModel

    def initialize_model(self, json_string: str) -> None:
        data = json.loads(json_string)
        sequential = tf.keras.Sequential.from_config(data['config'])
        self.model = NetworkModel(sequential)
    
    def update_model(self, json_string: str) -> None:
        data = json.loads(json_string)
        self.model.set_weights([tf.convert_to_tensor(w) for w in data['weights']])

    def train_local(self) -> None:
        #self.model.fit(train_data)    
        return

    def get_weights(self) -> str:
        weights = [w.tolist() for w in self.model.get_weights()]
        return json.dumps({"weights": weights})

