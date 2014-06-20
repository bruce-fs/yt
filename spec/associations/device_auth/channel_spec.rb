# encoding: UTF-8

require 'spec_helper'
require 'yt/models/channel'

describe Yt::Channel, :device_app do
  subject(:channel) { Yt::Channel.new id: id, auth: $account }

  context 'given someone else’s channel' do
    let(:id) { 'UCxO1tY8h1AhOz0T4ENwmpow' }

    it 'returns valid snippet data' do
      expect(channel.snippet).to be_a Yt::Snippet
      expect(channel.title).to be_a String
      expect(channel.description).to be_a Yt::Description
      expect(channel.thumbnail_url).to be_a String
      expect(channel.published_at).to be_a Time
    end

    it { expect(channel.status).to be_a Yt::Status }
    it { expect(channel.statistics_set).to be_a Yt::StatisticsSet }
    it { expect(channel.videos).to be_a Yt::Collections::Videos }
    it { expect(channel.videos.first).to be_a Yt::Video }
    it { expect(channel.playlists).to be_a Yt::Collections::Playlists }
    it { expect(channel.playlists.first).to be_a Yt::Playlist }
    it { expect{channel.create_playlist}.to raise_error Yt::Errors::RequestError }
    it { expect{channel.delete_playlists}.to raise_error Yt::Errors::RequestError }
    it { expect(channel.subscriptions).to be_a Yt::Collections::Subscriptions }

    # NOTE: These tests are slow because we *must* wait some seconds between
    # subscribing and unsubscribing to a channel, otherwise YouTube will show
    # wrong (cached) data, such as a user is subscribed when he is not.
    context 'that I am not subscribed to', :slow do
      before { channel.unsubscribe }
      it { expect(channel.subscribed?).to be false }
      it { expect(channel.subscribe!).to be_truthy }
    end

    context 'that I am subscribed to', :slow do
      before { channel.subscribe }
      it { expect(channel.subscribed?).to be true }
      it { expect(channel.unsubscribe!).to be_truthy }
    end
  end

  context 'given my own channel' do
    let(:id) { $account.channel.id }
    let(:title) { 'Yt Test title' }
    let(:description) { 'Yt Test description' }
    let(:tags) { ['Yt Test Tag 1', 'Yt Test Tag 2'] }
    let(:privacy_status) { 'unlisted' }
    let(:params) { {title: title, description: description, tags: tags, privacy_status: privacy_status} }

    describe 'playlists can be added' do
      after { channel.delete_playlists params }
      it { expect(channel.create_playlist params).to be_a Yt::Playlist }
      it { expect{channel.create_playlist params}.to change{channel.playlists.count}.by(1) }
    end

    describe 'playlists can be deleted' do
      let(:title) { "Yt Test Delete All Playlists #{rand}" }
      before { channel.create_playlist params }

      it { expect(channel.delete_playlists title: %r{#{params[:title]}}).to eq [true] }
      it { expect(channel.delete_playlists params).to eq [true] }
      it { expect{channel.delete_playlists params}.to change{channel.playlists.count}.by(-1) }
    end

    # NOTE: This test is just a reflection of YouTube irrational behavior of
    # raising a 500 error when you try to subscribe to your own channel,
    # rather than a more logical 4xx error. Hopefully this will get fixed
    # and this code (and test) removed.
    it { expect{channel.subscribe}.to raise_error Yt::Errors::ServerError }
  end

  context 'given an unknown channel' do
    let(:id) { 'not-a-channel-id' }

    it { expect{channel.snippet}.to raise_error Yt::Errors::NoItems }
    it { expect{channel.status}.to raise_error Yt::Errors::NoItems }
    it { expect{channel.statistics_set}.to raise_error Yt::Errors::NoItems }
    it { expect{channel.subscribe}.to raise_error Yt::Errors::RequestError }

    describe 'starting with UC' do
      let(:id) { 'UC-not-a-channel-id' }

      # NOTE: This test is just a reflection of YouTube irrational behavior of
      # returns 0 results if the name of an unknown channel starts with UC, but
      # returning 100,000 results otherwise (ignoring the channel filter).
      it { expect(channel.videos.count).to be 0 }
    end
  end
end