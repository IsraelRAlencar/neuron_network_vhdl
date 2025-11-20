import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import math
from typing import Tuple

# Dados XOR
X = torch.tensor([[0.,0.],[0.,1.],[1.,0.],[1.,1.]], dtype=torch.float32)
Y = torch.tensor([[0.],[1.],[1.],[0.]], dtype=torch.float32)

class MLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(2, 2, bias=True)  # 2->2
        self.act = nn.ReLU()                   # hidden
        self.fc2 = nn.Linear(2, 1, bias=True)  # 2->1 (logit)
    def forward(self, x):
        x = self.act(self.fc1(x))
        x = self.fc2(x)  # logit (linear)
        return x

def train_once(seed: int = 0, lr=0.05, epochs=2000) -> MLP:
    torch.manual_seed(seed)
    model = MLP()
    opt = optim.Adam(model.parameters(), lr=lr)
    loss_fn = nn.BCEWithLogitsLoss()
    model.train()
    for _ in range(epochs):
        opt.zero_grad()
        ylogits = model(X)
        loss = loss_fn(ylogits, Y)
        loss.backward()
        opt.step()
    return model.eval()

def export_params(model: MLP):
    with torch.no_grad():
        W1 = model.fc1.weight.detach().cpu().numpy()  # shape (2,2)
        b1 = model.fc1.bias.detach().cpu().numpy()    # shape (2,)
        W2 = model.fc2.weight.detach().cpu().numpy()  # shape (1,2)
        b2 = model.fc2.bias.detach().cpu().numpy()    # shape (1,)
    return W1, b1, W2, b2

# Q16.16 do seu VHDL
INT_BITS  = 16
FRAC_BITS = 16
S = 2**FRAC_BITS
MIN_VAL = - (2**(INT_BITS-1))
MAX_VAL = (2**(INT_BITS-1)) - (1.0 / S)

def quantize(x: float) -> float:
    xq = round(float(x) * S) / S
    if xq < MIN_VAL: xq = MIN_VAL
    if xq > MAX_VAL: xq = MAX_VAL
    return xq

def hw_forward_float(W1,b1,W2,b2, x):  # replica o hardware: hidden=ReLU, saida=logit
    # x: numpy shape (2,)
    h = np.maximum(0.0, b1 + W1 @ x)      # ReLU
    s = b2[0] + (W2 @ h.reshape(2,1))[0,0]  # logit (linear)
    y_bit = 1 if s > 0.0 else 0            # threshold no último estágio
    return s, y_bit

def hw_forward_quantized(W1,b1,W2,b2, x):
    # aplica quantização Q16.16 em TODOS os coeficientes e opera em float com os valores quantizados
    b1q = np.array([quantize(v) for v in b1])
    W1q = np.array([[quantize(v) for v in row] for row in W1])
    b2q = np.array([quantize(b2[0])])
    W2q = np.array([[quantize(v) for v in W2[0]]])

    # também pode quantizar inputs como 0.0/1.0 exatos (já são)
    xq = np.array([quantize(v) for v in x])

    h = np.maximum(0.0, b1q + W1q @ xq)
    s = b2q[0] + (W2q @ h.reshape(2,1))[0,0]
    y_bit = 1 if s > 0.0 else 0
    return s, y_bit

def check_accuracy(W1,b1,W2,b2):
    xs = [np.array([0.0,0.0]),
          np.array([0.0,1.0]),
          np.array([1.0,0.0]),
          np.array([1.0,1.0])]
    y_true = [0,1,1,0]

    ok_float = 0; ok_quant = 0
    print("Verificação float (antes da quantização):")
    for i,x in enumerate(xs):
        s, yb = hw_forward_float(W1,b1,W2,b2, x)
        print(f"  x={x}, logit={s:.6f}, y={yb}, esperado={y_true[i]}")
        ok_float += (yb==y_true[i])

    print("Verificação Q16.16 (após quantização):")
    for i,x in enumerate(xs):
        s, yb = hw_forward_quantized(W1,b1,W2,b2, x)
        print(f"  x={x}, logit_q={s:.6f}, y_q={yb}, esperado={y_true[i]}")
        ok_quant += (yb==y_true[i])

    return ok_float==4, ok_quant==4

def emit_vhdl_weights(W1,b1,W2,b2):
    weights = []
    # Camada 0: 2 neurônios, entradas=2 → (bias,w0,w1) por neurônio
    for n in range(2):
        weights.append(quantize(b1[n]))
        weights.append(quantize(W1[n,0]))  # w0 * x0
        weights.append(quantize(W1[n,1]))  # w1 * x1
    # Saída: 1 neurônio, entradas=2
    weights.append(quantize(b2[0]))
    weights.append(quantize(W2[0,0]))      # w0 * h0
    weights.append(quantize(W2[0,1]))      # w1 * h1

    print("constant NEURONS_PER_LAYER_C : integer_array(0 to 1) := (2, 1);")
    print(f"constant WEIGHTS_C : sfixed_bus_array(0 to {len(weights)-1}) := (")
    for i,w in enumerate(weights):
        sep = "," if i < len(weights)-1 else ""
        print(f"  to_sfixed_a({w}){sep}")
    print(");")

# Loop até conseguir 100% pós-quantização (limite de tentativas)
for seed in range(100):
    model = train_once(seed=seed, lr=0.05, epochs=2000)
    W1,b1,W2,b2 = export_params(model)
    ok_f, ok_q = check_accuracy(W1,b1,W2,b2)
    print(f"Seed {seed}: acc_float={ok_f}, acc_quant={ok_q}")
    if ok_q:
        print("Pesos aprovados pós-quantização Q16.16. Exportando VHDL:")
        emit_vhdl_weights(W1,b1,W2,b2)
        break
else:
    print("Tente aumentar épocas ou reduzir lr.")