#!/usr/bin/ruby
# Tiptoi "Manager"
#
# Loads the tiptoi XML file from http://www.tiptoi.com/db/tiptoi.xml and
# shows a list of available titles to be downloaded.
#

require 'nokogiri'
require 'open-uri'
require 'highline'

class TiptoiManager
  XML_URI = 'http://www.tiptoi.com/db/tiptoi.xml'

  def load
    @doc || @doc = Nokogiri::XML(open(XML_URI))
  end

  def categories
    load
    result = {}
    @doc.xpath('//categories/category').each do |category|
      name = category.at_xpath('name').content
      result[name.to_sym] = category['id'] unless name.empty?
      # puts "#{category['id']}: #{category.at_xpath('name').content}"
    end
    result
  end

  def books(category)
    selector = '//products/product'
    selector += "[categoryRef=\"#{category}\"]" if category
    result = {}
    @doc.xpath(selector).each do |product|
      result[product.at_xpath('name').content] = product['id']
    end
    result
  end

  def details(id)
    selector = "//products/product[@id=\"#{id}\"]"
    result = {}
    @doc.xpath(selector).each do |product|
      result = {
        name: product.at_xpath('name').content,
        subtitle: product.at_xpath('subtitle').content,
        description: product.at_xpath('description').content,
        url: product.at_xpath('gameFile/path').content
      }
    end
    result
  end

  def download(id)
    selector = "//products/product[@id=\"#{id}\"]"
    @doc.xpath(selector).each do |product|
      url = product.at_xpath('gameFile/path').content
      file_name = url.rpartition('/')[2]
      puts "\nDownload: #{url} nach #{file_name}"
      url = URI::encode(url)
      open(file_name, 'wb') do |file|
        file << open(url).read
      end
      puts "Fertig\n\n"
    end
  end
end

class MenuSystem < HighLine
  def run
    @manager = TiptoiManager.new
    show_main_menu
  end

  def show_main_menu
    loop do
      choose do |menu|
        menu.prompt = "Auswahl"
        @manager.categories.each do |name, index|
          menu.choice(name) { show_books(index) }
        end
        menu.choice(:Alle) { show_books(nil) }
        menu.choice(:Exit) { exit }
      end
    end
  end

  def show_books(category)
    choose do |menu|
      menu.prompt = "Auswahl"
      @manager.books(category).each do |name, id|
        menu.choice(name) { show_book(id) }
      end
      menu.choice(:Zurück) { return }
    end
  end

  def show_book(id)
    details = @manager.details(id)
    puts "\n\nBuch: #{details[:name]}\n#{details[:subtitle]}\n\n"
    puts "#{details[:description]}\n\n"
    do_download = ask("Download?  ") { |q| q.default = "n" }
    @manager.download(id) if ['Y', 'J'].include?(do_download.upcase)
  end
end

MenuSystem.new.run
