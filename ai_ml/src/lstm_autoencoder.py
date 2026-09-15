"""
HoneyChain LSTM Autoencoder

Used for temporal anomaly detection.

Input:
    Sequence of 36 observations
    = 6 hours at 10-minute intervals

Features:
    temperature
    humidity
    weight
    acoustics
"""

import torch
from torch import nn


class LSTMAutoencoder(nn.Module):

    def __init__(
        self,
        n_features: int,
        hidden_size: int = 64,
        latent_size: int = 32,
    ):

        super().__init__()

        # ----------------------------------------------------
        # Encoder
        # ----------------------------------------------------

        self.encoder = nn.LSTM(
            input_size=n_features,
            hidden_size=hidden_size,
            batch_first=True,
        )

        self.to_latent = nn.Linear(
            hidden_size,
            latent_size,
        )

        # ----------------------------------------------------
        # Latent -> decoder representation
        # ----------------------------------------------------

        self.from_latent = nn.Linear(
            latent_size,
            hidden_size,
        )

        # ----------------------------------------------------
        # Decoder
        # ----------------------------------------------------

        self.decoder = nn.LSTM(
            input_size=hidden_size,
            hidden_size=hidden_size,
            batch_first=True,
        )

        self.output = nn.Linear(
            hidden_size,
            n_features,
        )


    def forward(self, x):

        # x:
        # [batch, sequence_length, features]

        _, (hidden, _) = self.encoder(x)

        # Last encoder hidden state
        encoded = hidden[-1]

        # Compress into latent representation
        latent = self.to_latent(encoded)

        # Convert latent representation back
        decoder_hidden = torch.tanh(
            self.from_latent(latent)
        )

        decoder_hidden = decoder_hidden.unsqueeze(0)

        decoder_cell = torch.zeros_like(
            decoder_hidden
        )

        # Repeat latent representation across sequence
        decoder_input = (
            decoder_hidden[-1]
            .unsqueeze(1)
            .repeat(
                1,
                x.size(1),
                1,
            )
        )

        reconstructed, _ = self.decoder(
            decoder_input,
            (
                decoder_hidden,
                decoder_cell,
            ),
        )

        reconstructed = self.output(
            reconstructed
        )

        return reconstructed, latent