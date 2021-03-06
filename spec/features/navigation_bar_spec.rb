# Copyright (c) 2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
require_relative "feature_spec_helper"

RSpec.describe "Navigation Bar Buttons", type: :feature do
  initialize_system_description_factory_store

  let(:store) { system_description_factory_store }

  def nav_scopes
    all(".scope-navigation a.btn-sm:not(.disabled) span").map(&:text)
  end

  def content_scopes
    all("#content_container a.btn-lg span").map(&:text)
  end

  before(:each) do
    Server.set :system_description_store, store
  end

  context "when showing a system description" do
    before(:each) do
      description
    end

    let(:description) {
      create_test_description(
        scopes:        ["os", "packages", "repositories", "services"],
        name:          "name",
        store:         store,
        store_on_disk: true
      )
    }

    it "disables buttons whose scope was excluded" do
      visit("/name")

      within(".scope-navigation") do
        expect(find_link("UF")[:class]).to include("disabled")
      end
    end

    it "displays in the same order as the scopes" do
      visit("/name")

      expect(nav_scopes).to eq(content_scopes)
    end

    context "when hovered over a button" do
      it "shows a help text" do
        visit("/name")

        within(".scope-navigation") do
          link = find_link("OS")
          help_title = Nokogiri::HTML(link["data-original-title"]).text
          help_text = Nokogiri::HTML(link["data-content"]).text
          link.hover
          expect(find(".popover")).to have_content("#{help_title} #{help_text}")
        end
      end
    end
  end

  context "when comparing two system descriptions" do
    before(:each) do
      description_a
      description_b
    end

    let(:description_a) {
      create_test_description(
        scopes:        ["os", "packages", "repositories"],
        name:          "description_a",
        store:         store,
        store_on_disk: true
      )
    }
    let(:description_b) {
      create_test_description(
        scopes:        ["os", "packages", "repositories", "services"],
        name:          "description_b",
        store:         store,
        store_on_disk: true
      )
    }

    it "disables buttons whose scope was excluded in both descriptions" do
      visit("/compare/description_a/description_b")

      within(".scope-navigation") do
        expect(find_link("UF")[:class]).to include("disabled")
      end
    end

    it "disables buttons whose scope was excluded in any of the two descriptions" do
      visit("/compare/description_a/description_b")

      within(".scope-navigation") do
        expect(find_link("S")[:class]).to include("disabled")
      end
    end

    it "displays in the same order as the scopes" do
      visit("/compare/description_a/description_b")

      expect(nav_scopes).to eq(content_scopes)
    end
  end
end
